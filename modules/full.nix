{ self, ... }:
{
  flake.nixosModules.full = { config, ... }: {
    imports = with self.nixosModules; [
      base

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

        fullPkgs
      ];

      home-manager.users.${config.system.primaryUser} = self.homeModules.full;
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
