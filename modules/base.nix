{ self, ... }: {
  flake.nixosModules.base = {
    imports = with self.nixosModules; [
      home
      common
      nix-daemon
      user
      fish
      lazygit
      neovim
      yazi
      tmux
      pi
      git
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
      fish
      lazygit
      neovim
      yazi
      tmux
      pi
      git
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
      nix-daemon
      user
      fish
      lazygit
      neovim
      yazi
      tmux
      pi
      git
      basePkgs
    ];
  };

  flake.droidModules.base = {
    imports = with self.droidModules; [
      common
      fish
      lazygit
      neovim
      yazi
      tmux
      pi
      git
      nix-daemon
      home
      font
      basePkgs
    ];
  };

}
