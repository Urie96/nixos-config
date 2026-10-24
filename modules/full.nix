{ self, ... }:
{
  flake.nixosModules.full = { config, ... }: {
    imports = with self.nixosModules; [
      base

      rclone
      himalaya
      mbsync
      notmuch
      mitmproxy
      vdirsyncer
      todoman

      fullPkgs
    ];

    home-manager.users.${config.my.mainUser.name} = self.homeModules.full;
  };

  flake.darwinModules.full =
    {
      pkgs,
      config,
      inputs',
      ...
    }:
    {
      imports = with self.darwinModules; [
        base
        yabai
        skhd
        homebrew
        font

        rclone
        himalaya
        mbsync
        notmuch
        mitmproxy
        vdirsyncer
        todoman
        kitty

        fullPkgs
      ];

      home-manager.users.${config.system.primaryUser} = {
        imports = with self.homeModules; [
          full
          zen-browser
        ];
      };
    };

  flake.homeModules.full = {
    imports = with self.homeModules; [
      base
      dotfiles
    ];
  };

  flake.sysModules.full = { config, ... }: {
    imports = with self.sysModules; [
      base
      rclone
      himalaya
      mbsync
      notmuch
      mitmproxy
      vdirsyncer
      todoman
      fullPkgs
    ];

    home-manager.users.${config.my.mainUser.name} = self.homeModules.full;
  };

  flake.droidModules.full =
    {
      config,
      inputs',
      self',
      pkgs,
      ...
    }:
    {
      imports = with self.droidModules; [
        base
        audio
        update-dns
      ];

      home-manager.config = self.homeModules.full;
    };
}
