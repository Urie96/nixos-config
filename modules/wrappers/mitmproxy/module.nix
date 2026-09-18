{
  flake.wrappers.mitmproxy =
    # mitmproxy wrapper 模块（通用部分）。本机的配置和 CA 见 ./default.nix。
    #
    # confdir 默认放 $XDG_RUNTIME_DIR（兜底 /tmp），是个可写的临时目录。启动时：
    #   1. mkdir -p <confdir>
    #   2. 把 store 里的公开文件软链进去：config.yaml / keys.yaml / addons / dhparam /
    #      客户端证书（mitmproxy-ca-cert.{pem,cer,p12}）
    #   3. 把 sops 渲染在 tmpfs 的 CA（私钥+证书）软链成 <confdir>/mitmproxy-ca.pem
    # 这样 store 里只有可公开的东西，私钥既不进 store 也不长期落盘。
    #
    # 为什么 confdir 不能直接指向 store（比如 pi 的 generatedConfig.placeholder）：
    # mitmproxy 只有一个 confdir，签名 CA 只能从 <confdir>/mitmproxy-ca.pem 读，
    # 而私钥不能进 store；另外它还会往 confdir 写 command_history / magisk zip
    # （dhparam 我们预置了，不需要它写）。
    #
    # 注意：mitmproxy 没有 `--config-dir` 参数；`--confdir` 已废弃，
    # 等价的写法是 `--set confdir=DIR`（本模块用的就是它）。
    {
      config,
      wlib,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config;

      # 全部用 store 里的路径，不依赖运行时的 PATH。
      coreutils = pkgs.coreutils;
      mkdir = lib.getExe' coreutils "mkdir";
      ln = lib.getExe' coreutils "ln";

      # 注意：lib.escapeShellArg 内部用 builtins.toString，会把 path 的 context 丢掉，
      # 导致 store 路径不会成为 derivation 的输入（沙箱里看不到）。先插值成字符串再转义即可。
      quote = x: lib.escapeShellArg "${x}";

      # confdir 允许写运行时变量（$XDG_RUNTIME_DIR、$HOME 等），脚本运行时再展开。
      confdir = wlib.escapeShellArgWithEnv cfg.confdir;

      # ---------------- config.yaml ----------------
      # configFile 优先于 settings；两者都没有时是 null，不生成 config.yaml。
      configYaml =
        if cfg.configFile != null then
          cfg.configFile
        else if cfg.settings != { } then
          (pkgs.formats.yaml { }).generate "mitmproxy-config.yaml" cfg.settings
        else
          null;

      # ---------------- CA ----------------
      # 直接从 mitmproxy 包里取它内置的 DEFAULT_DHPARAM，避免它在 confdir 里自己写一份。
      mitmproxyDhparam = pkgs.runCommandLocal "mitmproxy-dhparam.pem" { } ''
        ${pkgs.python3.withPackages (ps: [ ps.mitmproxy ])}/bin/python -c \
          'from mitmproxy.certs import DEFAULT_DHPARAM; import sys; sys.stdout.buffer.write(DEFAULT_DHPARAM)' > $out
      '';
      dhparamFile = if cfg.ca.dhparamFile != null then cfg.ca.dhparamFile else mitmproxyDhparam;

      # 只含证书的 p12（mitm.it 下载用）。证书是公开的，所以在 build 时生成。
      caCertP12 =
        pkgs.runCommandLocal "mitmproxy-ca-cert.p12" { nativeBuildInputs = [ pkgs.openssl ]; }
          ''
            openssl pkcs12 -export -nokeys -in ${cfg.ca.certFile} -out $out -passout pass:
          '';

      # ---------------- keys.yaml（console 键位） ----------------
      # 用 Nix option 描述，`pkgs.formats.yaml` 转成 mitmproxy 的 keys.yaml 格式：
      # 一个 `{ key, cmd, ctx? , help? }` 的列表。ctx 为空时不写该字段，mitmproxy 默认按 global 处理。
      keybindingsYaml =
        if cfg.keybindings == [ ] then
          null
        else
          (pkgs.formats.yaml { }).generate "mitmproxy-keys.yaml" (
            map (
              b:
              {
                inherit (b) key cmd;
              }
              // lib.optionalAttrs (b.ctx != [ ]) { inherit (b) ctx; }
              // lib.optionalAttrs (b.help != null) { inherit (b) help; }
            ) cfg.keybindings
          );

      # ---------------- 要软链进 confdir 的公开文件 ----------------
      # 属性名是相对 confdir 的路径，值是 store 路径（或 store 里的 derivation）。
      publicFiles =
        (lib.optionalAttrs (cfg.manageConfig && configYaml != null) {
          "config.yaml" = configYaml;
        })
        // (lib.optionalAttrs (keybindingsYaml != null) {
          "keys.yaml" = keybindingsYaml;
        })
        // (lib.optionalAttrs (cfg.ca.clientCerts && cfg.ca.certFile != null) {
          "mitmproxy-ca-cert.pem" = cfg.ca.certFile;
          "mitmproxy-ca-cert.cer" = cfg.ca.certFile;
          "mitmproxy-ca-cert.p12" = caCertP12;
        })
        // {
          "mitmproxy-dhparam.pem" = dhparamFile;
        }
        // cfg.confdirFiles;

      # 所有公开产物在 wrapper 输出里的目录：$out/<binName>-conf/
      confDirName = "${config.binName}-conf";

      dirOf =
        rel:
        let
          d = lib.concatStringsSep "/" (lib.init (lib.splitString "/" rel));
        in
        if d == "" then confdir else "${confdir}/${d}";

      linkSteps = lib.mapAttrsToList (rel: _: [
        "${mkdir} -p ${dirOf rel}"
        "${ln} -sfn ${quote config.constructFiles.${rel}.path} ${confdir}/${lib.escapeShellArg rel}"
      ]) publicFiles;

      # 秘密文件（sops 渲染出来的 mitmproxy-ca.pem = 私钥 + 证书）。
      secretSteps = lib.optionals (cfg.ca.pemFile != null) [
        "${ln} -sfn ${wlib.escapeShellArgWithEnv cfg.ca.pemFile} ${confdir}/mitmproxy-ca.pem"
      ];

      setupSteps = [ "${mkdir} -p ${confdir}" ] ++ lib.flatten linkSteps ++ secretSteps;

      # 第一个 binary 作为 wrapper 的主程序。
      mainBinary =
        if cfg.binaries == [ ] then
          throw "mitmproxy: `binaries` 不能为空（第一个元素会作为 wrapper 的主程序）"
        else
          builtins.head cfg.binaries;
    in
    {
      imports = [
        wlib.modules.default
      ];

      options = {
        settings = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.nullOr (
              lib.types.oneOf [
                lib.types.bool
                lib.types.int
                lib.types.float
                lib.types.str
                (lib.types.listOf (
                  lib.types.oneOf [
                    lib.types.str
                    lib.types.int
                  ]
                ))
              ]
            )
          );
          default = { };
          example = lib.literalExpression ''
            {
              # mitmproxy 的 mode 是 Sequence[str]，所以要写成列表。
              mode = [ "regular" ];
              listen_port = 8080;
              # scripts 里的相对路径是相对 config.yaml 所在目录（也就是 confdir）解析的。
              scripts = [ "addons/addons.py" ];
            }
          '';
          description = ''
            写进 `config.yaml` 的 mitmproxy 全局选项。键名就是 mitmproxy 的 option 名
            （`mitmproxy --options` 可以看到全部），值可以是 bool / int / float / str / [str]，
            `null` 表示不使用该键（走 mitmproxy 自己的默认值）。
          '';
        };

        configFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "直接给一份现成的 config.yaml，优先级高于 `settings`。";
        };

        keybindings = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                key = lib.mkOption {
                  type = wlib.types.nonEmptyLine;
                  description = "键位，比如 `ctrl q` / `c` / `F`。";
                };
                cmd = lib.mkOption {
                  type = lib.types.str;
                  description = "要执行的 console 命令，可以是多行。";
                };
                ctx = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "生效的 console context（flowlist / flowview / global ...）；空 = 不写 ctx，mitmproxy 默认按 global。";
                };
                help = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "可选帮助文本。";
                };
              };
            }
          );
          default = [ ];
          example = lib.literalExpression ''
            [
              { key = "ctrl q"; cmd = "console.exit"; }
              {
                key = "H";
                ctx = [ "flowlist" ];
                cmd = "console.command.set custom_env\n";
              }
            ]
          '';
          description = ''
            写进 `keys.yaml` 的 console 键位（列表，字段和 mitmproxy 的 keys.yaml 一致）。
            为空时不生成 keys.yaml，mitmproxy 用自己的内置键位。
          '';
        };

        confdir = lib.mkOption {
          type = wlib.types.nonEmptyLine;
          default = "\${XDG_RUNTIME_DIR:-/tmp}/${config.binName}";
          defaultText = "\"\${XDG_RUNTIME_DIR:-/tmp}/<binName>\"";
          example = ".mitmproxy";
          description = ''
            mitmproxy 的配置目录（→ `--set confdir=...`），同时是读和写的位置。
            默认是 tmpfs 上的 `$XDG_RUNTIME_DIR/<binName>`（兜底 `/tmp/<binName>`），
            因为所有需要长期存在的东西（config、addons、CA）都是 store/sops 提供的软链，
            只剩下 command_history、magisk zip 这类临时文件才需要写。
            可以写运行时变量，也可以写相对路径（相对于 mitmproxy 的工作目录）。

            注意：如果不设置 `ca.pemFile`，mitmproxy 会在 confdir 里自己生成 CA，
            而默认 confdir 在 tmpfs 上、重启就没了 —— 那种情况请把 confdir 指到持久目录。
          '';
        };

        ca = {
          pemFile = lib.mkOption {
            type = lib.types.nullOr wlib.types.nonEmptyLine;
            default = null;
            example = lib.literalExpression ''config.sops.templates."mitmproxy-ca.pem".path'';
            description = ''
              合一的 CA 文件（私钥 + 证书，即 mitmproxy 的 `mitmproxy-ca.pem`），
              一般是 sops 渲染到 tmpfs 的运行时路径；本模块只做软链，不复制内容。
              null（默认）时 mitmproxy 按老样子自己生成/读取 `$confdir/mitmproxy-ca.pem`。
            '';
          };

          certFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            example = lib.literalExpression "./mitmproxy-ca-cert.pem";
            description = ''
              CA 证书 PEM（公开，可以进 store）。`clientCerts = true` 时软链成
              `mitmproxy-ca-cert.pem` / `.cer`，并用 openssl 生成 `.p12`。
            '';
          };

          dhparamFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            defaultText = lib.literalExpression "mitmproxy 内置的 DEFAULT_DHPARAM";
            description = ''
              DH 参数文件。默认从 mitmproxy 包里取出它内置的常量软链过去，
              这样 mitmproxy 不会在 confdir 里自己写 `mitmproxy-dhparam.pem`。
            '';
          };

          clientCerts = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "是否软链/生成给客户端安装用的 `mitmproxy-ca-cert.{pem,cer,p12}`（需要 `certFile`）。";
          };
        };

        confdirFiles = lib.mkOption {
          type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.str);
          default = { };
          example = lib.literalExpression ''
            {
              "keys.yaml" = ./keys.yaml;
              "addons/my_addon.py" = ./addons/my_addon.py;
            }
          '';
          description = ''
            除 config.yaml / CA 之外，还要软链进 `confdir` 的 store 文件。
            属性名是相对 confdir 的路径（可以带 `/`，会自动建目录）。
            只能是 store 里的静态路径；sops 渲染的运行时路径用 `ca.pemFile`。
          '';
        };

        generatedConfig.output = lib.mkOption {
          type = lib.types.str;
          default = config.outputName;
          description = "生成公开产物的那个 derivation output。";
        };

        generatedConfig.placeholder = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "${placeholder config.generatedConfig.output}/${confDirName}";
          defaultText = lib.literalExpression ''"''${placeholder config.generatedConfig.output}/<binName>-conf"'';
          description = ''
            wrapper 输出里那个公开产物目录的占位符路径（`${placeholder "out"}/<binName>-conf`）。
            里面是 config.yaml / keys.yaml / addons / dhparam / 客户端证书，全是可公开的文件；
            启动时它们会被逐个软链进 `confdir`，CA 私钥不在这里。
          '';
        };

        binaries = lib.mkOption {
          type = lib.types.listOf wlib.types.nonEmptyLine;
          default = [
            "mitmproxy"
            "mitmdump"
            "mitmweb"
          ];
          description = ''
            要包装的可执行文件。第一个作为 wrapper 的主程序，其余的通过
            `wrapperVariants` 一起产出到同一个 wrapper 里（共享这里的全部选项）。
          '';
        };

        manageConfig = lib.mkOption {
          type = lib.types.bool;
          default = cfg.settings != { } || cfg.configFile != null;
          defaultText = lib.literalExpression "config.settings != {} || config.configFile != null";
          description = "是否把 config.yaml 软链进 `confdir`（关掉就完全由你自己维护这个文件）。";
        };
      };

      config = {
        package = lib.mkDefault pkgs.mitmproxy;

        # 第一个 binary 作为主程序，其余的做成 wrapperVariants。
        binName = lib.mkDefault mainBinary;
        exePath = lib.mkDefault (
          lib.optionalString (config.binDir != null) "${config.binDir}/" + mainBinary
        );
        wrapperVariants = lib.genAttrs (builtins.tail cfg.binaries) (_: { });

        # 公开产物全部先在 wrapper 输出里生成一份 <binName>-conf/，运行时再软链到 confdir。
        # 这样 result 里能看到完整目录，且源路径都固定在 wrapper 自己的输出里。
        constructFiles = lib.mapAttrs' (
          rel: src:
          lib.nameValuePair rel {
            relPath = "${confDirName}/${rel}";
            builder = "cp -R ${quote src} \"$2\"";
          }
        ) publicFiles;

        runShell = [
          {
            name = "MITMPROXY_CONFDIR";
            # CA 是 SOPS_RENDER 渲染出来的，软链它必须排在后面。
            after = [ "SOPS_RENDER" ];
            data = lib.concatLines setupSteps;
          }
        ];

        flags."--set" = {
          data = "confdir=${cfg.confdir}";
          esc-fn = wlib.escapeShellArgWithEnv;
        };
      };
    };
}
