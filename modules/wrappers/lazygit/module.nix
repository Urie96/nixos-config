{
  flake.wrappers.lazygit =
    {
      config,
      wlib,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];

      options.settings = lib.mkOption {
        type = (pkgs.formats.yaml { }).type;
        default = { };
        description = ''
          lazygit 的 config.yml 内容，写入 wrapper 输出里的 config.yml，
          再由 `LG_CONFIG_FILE` 指向它。

          可用选项见
          <https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md>。
        '';
      };

      config = {
        package = lib.mkDefault pkgs.lazygit;

        env.LG_CONFIG_FILE = (pkgs.formats.yaml { }).generate "lazygit-config.yml" config.settings;

      };
    };
}
