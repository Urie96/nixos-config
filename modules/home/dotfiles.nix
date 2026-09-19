{
  flake.homeModules.dotfiles =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      config = {
        home.file = {
          ".config" = {
            source = ./dotConfig;
            recursive = true;
          };
        }
        // (lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          "Library/Rime" = {
            # pkgs.rime-ice 由 overlays.rime-ice 提供，已包含 emoji 补丁与
            # modules/overlays/rime-ice/custom 里的个人配置。
            source = "${pkgs.rime-ice}/share/rime-data";
            recursive = true;
          };
          "Library/Application Support/rbw/config.json".source = ./dotConfig/rbw/config.json;
        });
      };
    };
}
