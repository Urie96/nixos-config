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
      herdr
      pi
      git
      basePkgs
      catppuccin
    ];

  };

  # 注意：这里刻意不 import homeModules.common。
  # common 已经由上面的 nixos/darwin/sys/droid xModules.home 注入到同一个用户，
  # 两边都 import 会让 common 在每个 user 的 module 列表里出现两次，
  # 它一旦声明 options（如 home.seed）就会报 "is already declared"。
  flake.homeModules.base = {
    imports = with self.homeModules; [
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
      herdr
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
      herdr
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
      herdr
      pi
      git
      nix-daemon
      home
      font
      basePkgs
    ];
  };

}
