{
  flake.wrappers.rclone =
    {
      config,
      wlib,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        wlib.modules.default
      ];

      options = {
        settings = lib.mkOption {
          type = lib.types.attrsOf (lib.types.attrsOf (lib.types.nullOr wlib.types.stringable));
          default = { };
          description = ''
            rclone.conf 的 sections。值可以是字符串、path 或 derivation；
            值为 null 时省略该行。
          '';
        };

        configFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "直接给一个现成的 rclone.conf 文件，优先级高于 `settings`。";
        };

        configText = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "最终写进 rclone.conf 的文本（走 sops 时可能含 <SOPS:key:PLACEHOLDER>）。";
        };

        configPath = lib.mkOption {
          type = wlib.types.stringable;
          default = pkgs.writeText "rclone.conf" config.configText;
          description = "不启用 sops 时传给 `--config` 的路径。";
        };

        useSops = lib.mkOption {
          type = lib.types.bool;
          default = config.sops.secretsFile != null;
          defaultText = lib.literalExpression "config.sops.secretsFile != null";
          description = "是否把 rclone.conf 交给 sops 模块在运行时渲染。";
        };
      };

      config = lib.mkMerge [
        {
          package = lib.mkDefault pkgs.rclone;

          configText =
            if config.configFile != null then
              builtins.readFile config.configFile
            else
              lib.generators.toINIWithGlobalSection { } {
                globalSection = { };
                # null 表示省略这一行（生成器默认会把 null 打成字面量 "null"）
                sections = lib.mapAttrs (_: lib.filterAttrs (_: value: value != null)) config.settings;
              };

          flags."--config" = lib.mkDefault (
            if config.useSops then
              {
                data = config.sops.templates."rclone.conf".path;
                # 路径里有 $XDG_RUNTIME_DIR，需要运行时展开，不能用默认的 lib.escapeShellArg
                esc-fn = wlib.escapeShellArgWithEnv;
              }
            else
              config.configPath
          );
        }

        # 整条 template 都要条件化创建，否则 useSops = false 时也会多出一个空 template，
        # 让 sops.enable 变成 true。
        (lib.mkIf config.useSops {
          sops.templates."rclone.conf".content = config.configText;
        })
      ];
    };
}
