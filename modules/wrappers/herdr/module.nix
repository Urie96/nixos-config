{
  flake.wrappers.herdr =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    let
      tomlFormat = pkgs.formats.toml { };
    in
    {
      imports = [ wlib.modules.default ];

      options.settings = lib.mkOption {
        type = tomlFormat.type;
        default = { };
        description = ''
          herdr `config.toml` 的内容。生成到 wrapper 输出里的 `$out/${config.binName}/config.toml`，
          再由 `HERDR_CONFIG_PATH` 指向它。

          字段含义见 <https://herdr.dev/llms.txt>，写完用 `herdr config check` 校验；
          注释掉的默认值不用抄，只写真正改过的项。
        '';
      };

      config = {
        package = lib.mkDefault pkgs.herdr;

        # 照 yazi 的 init.lua 那样，用通用的 constructFiles 把配置放进 wrapper 自己的输出：
        # relPath/output 用 mkOverride 0，和 wrapper 里其它生成文件待在同一个输出里，
        # 这样不会有额外的 store 路径指向别处。
        constructFiles.config = {
          content = builtins.readFile (tomlFormat.generate "herdr-config.toml" config.settings);
          relPath = lib.mkOverride 0 "${config.binName}/config.toml";
          output = lib.mkOverride 0 config.outputName;
        };

        # 引用时用 .path（占位符），wrapper 构建时会被改写成 $out 下的真实路径；
        # 用 .outPath 会让产物引到自己。
        #
        # HERDR_CONFIG_PATH 只换配置文件：会话状态（session.json、快照、日志、socket）
        # 仍然在 ~/.config/herdr/ 和 ~/.config/herdr/sessions/<name>/ 下，
        # 所以 store 里这份只读文件不影响 herdr 写状态。
        env.HERDR_CONFIG_PATH = config.constructFiles.config.path;
      };
    };
}
