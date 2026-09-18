{ inputs, ... }: {
  flake.wrappers.sops =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    let
      cfg = config.sops;

      # 自动解析 secrets 文件的结构（不解密）得到 key 名。
      # sops 只加密 value，key 是明文，所以这一步不需要私钥；
      # 但需要 eval 阶段能读到文件：只有 path literal 和 store path 可以，
      # 运行时路径（/home/... 之类）在纯 eval 下会报错。
      detectedKeys =
        if cfg.secretsFile == null then
          [ ]
        else if !(builtins.isPath cfg.secretsFile || lib.isStorePath (toString cfg.secretsFile)) then
          throw ''
            sops.keys 必须显式设置：${toString cfg.secretsFile} 不是 path literal / store path，
            eval 阶段读不到（纯 eval 不允许访问仓库外的绝对路径）。
            自动解析只支持 ./secrets.yaml 这类（会进 store 的）路径。
          ''
        else
          lib.importJSON (
            pkgs.runCommandLocal "sops-detected-keys.json" { } ''
              ${lib.getExe cfg.package} --list-keys \
                --secrets ${lib.escapeShellArg "${cfg.secretsFile}"} \
                ${lib.optionalString (cfg.format != null) "--format ${lib.escapeShellArg cfg.format}"} \
                > $out
            ''
          );

      # 运行时路径里允许出现的字符：$ {} 是留给运行时变量展开的（如 $XDG_RUNTIME_DIR），
      # 其余 shell 元字符一律禁止，避免生成的命令行被注入。
      pathAllowedChars = lib.stringToCharacters "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./~-: {},$";

      templateType = lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            content = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = ''
                模板内容。secret 用 `<SOPS:KEY:PLACEHOLDER>` 引用，KEY 是 secrets
                文件里扁平化后的 key（`db.password` → `db_password`），大小写精确匹配。
                设置了 `file` 时忽略此项。
              '';
            };
            file = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "直接指定模板文件，优先级高于 `content`。";
            };
            name = lib.mkOption {
              type = wlib.types.nonEmptyLine;
              default = name;
              description = "渲染出来的文件名，默认是 attr 名。";
            };
            path = lib.mkOption {
              type = wlib.types.nonEmptyLine;
              default = "${cfg.runtimeDir}/${config.name}";
              description = ''
                渲染结果的运行时路径。可以包含 `$VAR` / `''${VAR}`（wrapper 运行时展开），
                所以这里不要求文件在 eval 时存在。
              '';
            };
            template = lib.mkOption {
              type = lib.types.path;
              readOnly = true;
              description = "实际使用的模板文件（store path，不含任何秘密）。";
            };
          };
          config.template =
            if config.file != null then config.file else pkgs.writeText "sops-template-${name}" config.content;
        }
      );

      renderArgs = lib.concatLists (
        lib.mapAttrsToList (name: t: [
          "-m"
          (lib.escapeShellArg (toString t.template))
          "\"${t.path}\""
        ]) cfg.templates
      );

      renderCommand =
        lib.concatStringsSep " " (
          [
            (lib.getExe cfg.package)
            "-p" # 目标目录不存在时创建（$XDG_RUNTIME_DIR 下通常还没有）
            "--secrets"
            (lib.escapeShellArg "${cfg.secretsFile}")
          ]
          ++ lib.optionals (cfg.format != null) [
            "--format"
            cfg.format
          ]
          ++ lib.optionals (cfg.keyFile != null) [
            "--key-file"
            (lib.escapeShellArg (toString cfg.keyFile))
          ]
          ++ lib.optionals (cfg.keyCmd != null) [
            "--key-cmd"
            (lib.escapeShellArg cfg.keyCmd)
          ]
          ++ [
            "--mode"
            cfg.mode
          ]
          ++ renderArgs
          ++ cfg.extraArgs
        )
        + " || exit 1"; # wrapper 脚本没有 set -e，失败必须显式退出，不能带着空秘密启动 app

      # wrapper module 没有 NixOS 那样的 assertions 选项，所以这里自己收集问题，
      # 在生成 runShell 的内容时 throw。
      problems =
        lib.optionals (cfg.secretsFile == null) [ "启用后必须设置 sops.secretsFile" ]
        ++ lib.optionals (cfg.templates == { }) [ "启用后至少要有一个 sops.templates.<name>" ]
        ++ lib.optionals ((config.wrapperImplementation or "nix") == "binary") [
          "wrapperImplementation = \"binary\" 时 runShell 会被忽略，秘密不会被渲染，请改用 \"nix\" 或 \"shell\""
        ]
        ++ lib.optionals (builtins.match "[0-7]{3,4}" cfg.mode == null) [
          "sops.mode 必须是 3-4 位八进制，例如 0600"
        ]
        ++ lib.mapAttrsToList (name: t: "sops.templates.${name}.path 含有不允许的 shell 元字符: ${t.path}") (
          lib.filterAttrs (
            _: t: !(lib.all (c: builtins.elem c pathAllowedChars) (lib.stringToCharacters t.path))
          ) cfg.templates
        )
        ++ lib.mapAttrsToList (
          name: _: "sops.placeholder 的 key ${name} 不是合法名字（需要 ^[A-Za-z_][A-Za-z0-9_]*$）"
        ) (lib.filterAttrs (name: _: builtins.match "[A-Za-z_][A-Za-z0-9_]*" name == null) cfg.placeholder);
    in
    {
      # 只有这个模块自己的话，wrapper 里没有 runShell；显式 import 保证自包含。
      imports = [ wlib.modules.makeWrapper ];

      options.sops = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = cfg.templates != { };
          defaultText = lib.literalExpression "sops.templates != {}";
          description = "是否启用。默认只要声明了 template 就启用。";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.nur-packages.packages.${pkgs.stdenv.hostPlatform.system}.sops-render;
          defaultText = lib.literalExpression "self'.packages.sops-render";
          description = "提供 `sops-render` 的包。";
        };

        secretsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression "./secrets/pi.yaml";
          description = ''
            sops 加密的 secrets 文件（yaml 或 json，按扩展名推断）。放到 store 里是安全的
            （只有密文），但也可以给仓库外的绝对路径。
          '';
        };

        format = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "yaml"
              "json"
            ]
          );
          default = null;
          description = "覆盖按扩展名推断的 secrets 文件格式。";
        };

        keyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/home/urie/.config/sops/age/keys.txt";
          description = ''
            age 私钥文件（→ `--key-file`）。留空则交给 sops 自己找：
            环境变量 SOPS_AGE_KEY / SOPS_AGE_KEY_FILE / SOPS_AGE_KEY_CMD，
            以及 `$XDG_CONFIG_HOME/sops/age/keys.txt`；sops-render 里还有一条兜底，
            `/var/lib/sops-nix/key.txt` 存在时用它。
          '';
        };

        keyCmd = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "ssh-to-age -private-key -i ~/.ssh/id_ed25519";
          description = "执行该命令，用其输出作为 age 私钥（→ `--key-cmd`）。";
        };

        mode = lib.mkOption {
          type = wlib.types.nonEmptyLine;
          default = "0600";
          description = "所有渲染结果的权限（八进制）。";
        };

        runtimeDir = lib.mkOption {
          type = wlib.types.nonEmptyLine;
          default = "\${XDG_RUNTIME_DIR:-/tmp}/sops-render/${config.binName}";
          defaultText = lib.literalExpression ''"''${XDG_RUNTIME_DIR:-/tmp}/sops-render/''${config.binName}"'';
          description = ''
            渲染结果的根目录。默认放 tmpfs 里的 per-user 目录，重启自动清空。
            可以是普通绝对路径，也可以包含运行时变量；含变量时不能直接内插进 store
            里的配置文件（那种场景请用 NixOS 侧的 sops-nix）。
          '';
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.singleLineStr;
          default = [ ];
          description = "额外追加到 sops-render 命令行的参数（原样拼接，自行负责转义）。";
        };

        templates = lib.mkOption {
          type = lib.types.attrsOf templateType;
          default = { };
          description = "要渲染的模板。每个 template 一个输出文件。";
        };

        keys = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf wlib.types.nonEmptyLine);
          default = null;
          example = [ "anthropic_api_key" ];
          description = ''
            secrets key 名单。`null`（默认）= 从 `secretsFile` 自动解析；
            显式设置时覆盖自动解析（secretsFile 是运行时路径、eval 阶段读不到时用这个）。
          '';
        };

        detectedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          description = "从 `secretsFile` 自动解析出来的（扁平化后的）key 名，不解密。";
        };

        placeholder = lib.mkOption {
          type = lib.types.attrsOf lib.types.singleLineStr;
          default = lib.genAttrs (if cfg.keys != null then cfg.keys else cfg.detectedKeys) (
            name: "<SOPS:${name}:PLACEHOLDER>"
          );
          defaultText = lib.literalExpression ''lib.genAttrs (config.sops.keys or config.sops.detectedKeys) (name: "<SOPS:''${name}:PLACEHOLDER>")'';
          description = ''
            模板里引用的占位符字符串，默认由 `sops.keys` 生成：
            `config.sops.placeholder.db_password` → `<SOPS:db_password:PLACEHOLDER>`。
            也可以手动补不在 `keys` 里的条目。
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        sops.detectedKeys = detectedKeys;

        runShell = [
          {
            name = "SOPS_RENDER";
            data =
              if problems != [ ] then
                throw "sops 模块配置错误:\n- ${lib.concatStringsSep "\n- " problems}"
              else
                renderCommand;
          }
        ];
      };
    };
}
