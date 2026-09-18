{
  flake.wrappers.vdirsyncer =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    let
      # vdirsyncer 的配置是「INI 外壳 + JSON/TOML 值」：
      #   [storage remote]
      #   password.fetch = ["command", "rbw", "get", "example.com"]
      # 与 nixpkgs 的 services.vdirsyncer 保持一致：用 toINI 生成 section，
      # 每个值用 builtins.toJSON 序列化。
      jsonValue = lib.types.nullOr (
        lib.types.oneOf [
          lib.types.bool
          lib.types.int
          lib.types.float
          lib.types.str
          (lib.types.listOf jsonValue)
          (lib.types.attrsOf jsonValue)
        ]
      );

      section = lib.types.attrsOf jsonValue;

      # null 表示省略这个 key，而不是写成字面量 null。
      dropNulls = lib.filterAttrs (_: value: value != null);

      renderConfig =
        sections:
        lib.generators.toINI {
          mkKeyValue = lib.generators.mkKeyValueDefault { mkValueString = builtins.toJSON; } "=";
        } (lib.mapAttrs (_: dropNulls) sections);
    in
    {
      imports = [ wlib.modules.default ];

      options = {
        general = lib.mkOption {
          type = section;
          default = { };
          description = "`[general]` 段的内容，例如 `status_path`。";
        };

        pairs = lib.mkOption {
          type = lib.types.attrsOf section;
          default = { };
          example = lib.literalExpression ''
            {
              calendar = {
                a = "local_calendar";
                b = "remote_calendar";
                collections = [ "personal" "work" ];
              };
            }
          '';
          description = "`[pair <名字>]` 段，key 是 pair 名。";
        };

        storages = lib.mkOption {
          type = lib.types.attrsOf section;
          default = { };
          example = lib.literalExpression ''
            {
              local_calendar = {
                type = "filesystem";
                path = "~/.calendars/";
                fileext = ".ics";
              };
              remote_calendar = {
                type = "caldav";
                url = "https://caldav.example.com";
                username = "user";
                "password.fetch" = [ "command" "rbw" "get" "example.com" ];
              };
            }
          '';
          description = "`[storage <名字>]` 段，key 是 storage 名。";
        };

        configText = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "最终写入 vdirsyncer 配置文件的文本。";
        };

        configFile = lib.mkOption {
          type = wlib.types.file {
            path = lib.mkOptionDefault config.constructFiles.vdirsyncerConfig.path;
          };
          default = { };
          description = ''
            生成的配置文件。`content` 会追加到 `general`/`pairs`/`storages`
            生成的内容之后；直接指定 `path` 可以完全覆盖生成结果。
          '';
        };
      };

      config = {
        package = lib.mkDefault pkgs.vdirsyncer;

        configText =
          renderConfig (
            { inherit (config) general; }
            // lib.mapAttrs' (name: lib.nameValuePair "pair ${name}") config.pairs
            // lib.mapAttrs' (name: lib.nameValuePair "storage ${name}") config.storages
          )
          + "\n"
          + config.configFile.content;

        # 和 git 模块一样，把配置文件和 wrapper 放在同一个输出里，
        # 再用 VDIRSYNCER_CONFIG 指过去，避免产物自引用。
        constructFiles.vdirsyncerConfig = {
          relPath = "${config.binName}config";
          content = config.configText;
        };

        env.VDIRSYNCER_CONFIG = config.configFile.path;

        meta.description = "vdirsyncer，配置由 `general`/`pairs`/`storages` 生成。";
      };
    };
}
