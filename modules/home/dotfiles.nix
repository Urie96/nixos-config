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
          ".fzfrc".text = ''
            --bind='page-up:preview-page-up,page-down:preview-page-down'
            --cycle
            --color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8
            --color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC
            --color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8
            --color=selected-bg:#45475A
            --color=border:#6C7086,label:#CDD6F4
          '';
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
