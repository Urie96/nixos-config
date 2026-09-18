{
  flake.wrappers.kitty =
    {
      config,
      lib,
      pkgs,
      wlib,
      ...
    }:
    let
      inherit (lib)
        types
        mkIf
        mkOption
        mkOrder
        literalExpression
        ;

      # kitty 配置目录在 wrapper 输出里的名字，即 $out/kittyConfig
      confDirName = "kittyConfig";

      settingsValueType =
        with types;
        oneOf [
          str
          bool
          int
          float
        ];

      # 支持直接给字符串，或者给一个文件路径（如 ./config/open-actions.conf）
      contentValueType = types.either types.lines types.path;
      # path 在求值期读成内容，避免最后把 store 路径当内容写进配置文件
      toContent = value: if builtins.isPath value then builtins.readFile value else value;

      # scriptVars 的取值：package 用 lib.getExe 取可执行文件，path 原样使用
      scriptVarType = types.either types.package types.path;
      toScriptVar = value: if lib.isDerivation value then lib.getExe value else toString value;

      # 把所有 @NAME@ 替换成 scriptVars.NAME 的绝对路径（打包期完成，脚本不再需要查 PATH）
      substituteScriptVars =
        content:
        let
          names = builtins.attrNames config.scriptVars;
          pairs = map (name: {
            from = "@${name}@";
            to = toScriptVar config.scriptVars.${name};
          }) names;
        in
        builtins.replaceStrings (map (p: p.from) pairs) (map (p: p.to) pairs) content;

      # 和内置 kitty wrapper 的 settings 保持一致的序列化方式（布尔值写成 yes/no）
      toKittyConfig = lib.generators.toKeyValue {
        mkKeyValue =
          key: value:
          let
            yesNo = v: if v then "yes" else "no";
            value' = (if builtins.isBool value then yesNo else toString) value;
          in
          "${key} ${value'}";
      };

      # 在 $out/${confDirName}/<name> 下生成一个文件（name 可以带子目录）
      file = name: content: {
        "${confDirName}/${name}" = {
          relPath = "${confDirName}/${name}";
          content = substituteScriptVars (toContent content);
        };
      };
    in
    {
      imports = [ wlib.wrapperModules.kitty ];

      options = {
        kittyConfigDir = mkOption {
          type = types.str;
          readOnly = true;
          description = ''
            wrapper 输出里 kitty 配置目录的路径，即 `$out/kittyConfig`。

            它会通过 `KITTY_CONFIG_DIRECTORY` 传给 kitty 以及它启动的 kitten，
            所以 `kitten <name>.py`、`open-actions.conf`、`quick-access-terminal.conf`
            都会从这个目录读取。
          '';
        };

        clearAllShortcuts = mkOption {
          type = types.bool;
          default = false;
          description = ''
            是否在 `kitty.conf` 里写入 `clear_all_shortcuts yes`。

            kitty 的 `map` 是按行累积的，`clear_all_shortcuts` 会清掉它之前的所有
            映射（包括 kitty 自带的默认快捷键），所以这里的输出被放在所有 `map`
            之前，即 {option}`keybindings` 和 {option}`extraConfig` 里的映射会保留下来。
          '';
        };

        openActions = mkOption {
          type = contentValueType;
          default = "";
          description = ''
            写入 `$out/kittyConfig/open-actions.conf` 的内容，见
            <https://sw.kovidgoyal.net/kitty/open_actions/>。

            为空时不生成该文件。
          '';
        };

        quickAccessTerminal = mkOption {
          type = types.attrsOf settingsValueType;
          default = { };
          example = literalExpression ''
            {
              lines = 25;
              columns = 80;
              edge = "center-sized";
              hide_on_focus_loss = true;
              start_as_hidden = true;
            }
          '';
          description = ''
            写入 `$out/kittyConfig/quick-access-terminal.conf` 的配置项，
            由 `kitten quick-access-terminal` 读取，见
            <https://sw.kovidgoyal.net/kitty/kittens/quick-access-terminal/>。

            布尔值会写成 `yes`/`no`；需要写多值或原始行时用
            {option}`quickAccessTerminalExtraConfig`。
          '';
        };

        quickAccessTerminalExtraConfig = mkOption {
          type = contentValueType;
          default = "";
          description = "追加到 `quick-access-terminal.conf` 末尾的原始内容。";
        };

        scriptVars = mkOption {
          type = types.attrsOf scriptVarType;
          default = { };
          example = literalExpression ''
            {
              MPV = pkgs.mpv;
              RSYNC_TOOL = pkgs.writeShellApplication {
                name = "rsync-tool";
                runtimeInputs = [ pkgs.rsync pkgs.openssh pkgs.yazi ];
                text = "…";
              };
            }
          '';
          description = ''
            打包期注入到生成文件里的变量：键 `NAME` 会把文件内容中的 `@NAME@`
            替换成对应的绝对路径（{option}`scripts`、{option}`openActions`、
            {option}`quickAccessTerminal` 都在替换范围内）。

            值为 package 时用 `lib.getExe` 取可执行文件，为 path 时原样使用。
            想指向 store 之外的路径（比如 `/opt/homebrew/bin/mpv`）时要写成*字符串*，
            不加引号的路径字面量会被 Nix 复制进 store。
            这样脚本在运行时就不必再依赖 `PATH` 查找二进制。
          '';
        };

        scripts = mkOption {
          type = types.attrsOf contentValueType;
          default = { };
          example = literalExpression ''
            {
              "mykitten.py" = ./mykitten.py;
            }
          '';
          description = ''
            自定义 kitten：属性名是相对于 `$out/kittyConfig/` 的路径，内容会写到对应位置。
            属性名不带 `/` 时直接平铺在配置目录根下，可以用 `kitten <name>.py` 调用；

            见 <https://sw.kovidgoyal.net/kitty/kittens/custom/>。
          '';
        };
      };

      config = {
        kittyConfigDir = "${placeholder config.outputName}/${confDirName}";

        # kitty 启动的 kitten 会用 KITTY_CONFIG_DIRECTORY 解析 *.py、
        # open-actions.conf、quick-access-terminal.conf；并且 kitty 自己的文档说
        # 一旦设置了这个变量，就“always used and the above searching does not happen”，
        # 也就是不会再去读 ~/.config/kitty/kitty.conf。
        env.KITTY_CONFIG_DIRECTORY = config.kittyConfigDir;

        # 内置 kitty wrapper 还会用 flags."--config" 把 `--config <conf>` 加在所有参数最前面，
        # 但 kitty 的 `+runpy` / `+kitten` / `+complete` 这类子命令要求 argv[1] 以 '+' 开头，
        # 前置的 --config 会让它们退化成打开一个普通 kitty 窗口。
        # 上面的 KITTY_CONFIG_DIRECTORY 已经能让 kitty 只读我们的 kitty.conf，
        # 所以这里直接去掉 --config，保持用户的参数原样透传。
        flags."--config" = lib.mkForce null;

        # 排在内置模块的 map（mkOrder 560/570）和用户的 extraConfig（默认 order）之前
        extraConfig = mkIf config.clearAllShortcuts (
          mkOrder 500 ''
            clear_all_shortcuts yes
          ''
        );

        # macOS 上用 .app 启动时，macOS 执行的是 bundle 里的 CFBundleExecutable，
        # 而不是 $out/bin/kitty。内置的 symlinkScript 只把原 package 的
        # Applications/kitty.app 软链过来，nix-darwin 安装 /Applications/Nix Apps
        # 时用 rsync --copy-unsafe-links 把指向 store 的软链解引用成真实文件，
        # 于是 bundle 里的 kitty 就变回了没有 wrapper 的原始二进制。
        # 这里在 bundle 里再生成一个 wrapper（bin/kitty 那个保持不变），
        # 让 .app 启动时也带上 KITTY_CONFIG_DIRECTORY。
        #
        # 用 binary 实现（pkgs.makeBinaryWrapper）而不是 shell 脚本，
        # 和 nixpkgs 里 kitty 自己的 CFBundleExecutable 保持一致。
        wrapperVariants.app = {
          enable = pkgs.stdenv.hostPlatform.isDarwin;
          binDir = "Applications/kitty.app/Contents/MacOS";
          binName = "kitty";
          exePath = "Applications/kitty.app/Contents/MacOS/kitty";
          wrapperImplementation = "binary";
        };

        constructFiles = {
          # 内置 wrapper 把 kitty.conf 生成在输出的根目录，这里挪进 kittyConfig 目录，
          # KITTY_CONFIG_DIRECTORY/kittyConfigDir 会自动跟着指向新位置。
          kittyConfig.relPath = lib.mkForce "${confDirName}/${config.binName}.conf";
        }
        // lib.optionalAttrs (config.openActions != "") (file "open-actions.conf" config.openActions)
        //
          lib.optionalAttrs (config.quickAccessTerminal != { } || config.quickAccessTerminalExtraConfig != "")
            (
              file "quick-access-terminal.conf" ''
                ${toKittyConfig config.quickAccessTerminal}${config.quickAccessTerminalExtraConfig}
              ''
            )
        // lib.concatMapAttrs file config.scripts;
      };
    };
}
