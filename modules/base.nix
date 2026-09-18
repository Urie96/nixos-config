{ self, ... }: {
  flake.nixosModules.base = {
    imports = with self.nixosModules; [
      home
      common
      nix-daemon
      user
      fish
      basePkgs
      catppuccin
    ];

  };

  flake.homeModules.base = {
    imports = with self.homeModules; [
      common
      ssh
    ];
  };

  flake.darwinModules.base = {
    imports = with self.darwinModules; [
      home
      common
      rime
      nix-daemon
      basePkgs
    ];
  };

  flake.sysModules.base = {
    imports = with self.sysModules; [
      home
      common
      user
      fish
      basePkgs
    ];
  };

  flake.droidModules.base = {
    imports = with self.droidModules; [
      common
      nix-daemon
      home
      font
      basePkgs
    ];
  };

}
