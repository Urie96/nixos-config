{
  description = "NixOS configuration with flakes";

  nixConfig.extra-substituters = [
    "https://cache.lubui.com:8443"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.numtide.com"
    "https://urie96.cachix.org"
  ];
  nixConfig.extra-trusted-public-keys = [
    "cache.lubui.com-2:tfGYA7ZOj7ubsmDDpe4q5n4jl58lsbtOa0N5QMHt1dY="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "urie96.cachix.org-1:HvBaYVt8jaNXuLS1nLmaT0z6kD/sqWCFwSYdvd5Xwnk="
  ];

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    old-nixpkgs.url = "https://releases.nixos.org/nixos/unstable/nixos-26.11pre1086391.151fa4e8ddfd/nixexprs.tar.zst";

    nix-on-droid.url = "github:Urie96/nix-on-droid/testing";
    nix-on-droid.inputs.nixpkgs.follows = "nixpkgs";
    nix-on-droid.inputs.home-manager.follows = "home-manager";

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    import-tree.url = "github:vic/import-tree";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nur-packages.url = "github:Urie96/nur-packages";
    # nur-packages.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.inputs.treefmt-nix.follows = "treefmt-nix";

    niks3.url = "github:Mic92/niks3";
    niks3.inputs.nixpkgs.follows = "nixpkgs";
    niks3.inputs.treefmt-nix.follows = "treefmt-nix";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core.url = "github:homebrew/homebrew-core";
    homebrew-core.flake = false;

    homebrew-cask.url = "github:homebrew/homebrew-cask";
    homebrew-cask.flake = false;

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    data-mesher.url = "git+https://git.clan.lol/clan/data-mesher?shallow=1";
    data-mesher.inputs = {
      nixpkgs.follows = "nixpkgs";
      treefmt-nix.follows = "treefmt-nix";
      flake-parts.follows = "flake-parts";
    };

    systems.url = "github:nix-systems/default";

    clan-core.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
    clan-core.inputs = {
      nixpkgs.follows = "nixpkgs";
      sops-nix.follows = "sops-nix";
      treefmt-nix.follows = "treefmt-nix";
      data-mesher.follows = "data-mesher";
      disko.follows = "disko";
      flake-parts.follows = "flake-parts";
      systems.follows = "systems";
      nix-darwin.follows = "nix-darwin";
    };

    srvos.url = "github:nix-community/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    zen-browser.inputs.home-manager.follows = "home-manager";

    firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    firefox-addons.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    catppuccin-nix.url = "github:catppuccin/nix";
    catppuccin-nix.inputs.nixpkgs.follows = "nixpkgs";

    strace-macos.url = "github:Mic92/strace-macos";
    strace-macos.inputs.nixpkgs.follows = "nixpkgs";
    strace-macos.inputs.treefmt-nix.follows = "treefmt-nix";
    strace-macos.inputs.flake-parts.follows = "flake-parts";

    system-manager.url = "github:numtide/system-manager";
    system-manager.inputs.nixpkgs.follows = "nixpkgs";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    neovim-nightly-overlay.inputs.nixpkgs.follows = "nixpkgs";
    neovim-nightly-overlay.inputs.flake-parts.follows = "flake-parts";

    wrappers.url = "github:BirdeeHub/nix-wrapper-modules";
    wrappers.inputs.nixpkgs.follows = "nixpkgs";

    # nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    # nixos-raspberrypi.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      flake-parts,
      self,
      import-tree,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [
        inputs.wrappers.flakeModules.wrappers
        inputs.home-manager.flakeModules.home-manager
        inputs.clan-core.flakeModules.default
        (import-tree ./modules)
      ];

      # wrapper 的 `.install` 模块靠 `_class` 从 `config.modules.{nixos,darwin,...}` 里
      # 选安装行为。nixos/darwin 的 evalModules 会把 class 传给模块参数，直接 import 即可。
      flake.nixosModules = builtins.mapAttrs (_: v: v.install) self.wrappers;
      flake.darwinModules = builtins.mapAttrs (_: v: v.install) self.wrappers;

      # system-manager 的 evalModules 不传 class（模块参数 `_class` 是 null），install 模块
      # 里 `config.modules.${_class}` 会直接抛 "expected a string but found null"。
      # 这里显式调用 functor 把 `_class` 补成 "nixos"：system-manager 也有
      # environment.systemPackages，所以 install 行为可以直接复用 `modules.nixos` 那套。
      flake.sysModules = builtins.mapAttrs (
        _: v:
        { pkgs, ... }:
        {
          imports = [
            (v.install {
              _class = "nixos";
              inherit pkgs;
            })
          ];
        }
      ) self.wrappers;

      # nix-on-droid 的 evalModules 用 class = "nixOnDroid"，不在 wlib 内置的
      # nixos/darwin/homeManager/hjem 里，install 模块只会声明 `wrappers.<name>` 选项、
      # 不安装任何东西（`config.modules.${_class} or []` 拿到空列表）。
      # 所以这里 import 它只为拿到 `wrappers.<name>.{enable,wrapper}`，包自己塞进
      # nix-on-droid 的 environment.packages（nix-on-droid 没有 environment.systemPackages）。
      flake.droidModules = builtins.mapAttrs (
        name: v:
        {
          pkgs,
          config,
          lib,
          ...
        }:
        {
          imports = [
            (v.install {
              _class = "nixOnDroid";
              inherit pkgs;
            })
          ];
          environment.packages = lib.mkIf config.wrappers.${name}.enable [
            config.wrappers.${name}.wrapper
          ];
        }
      ) self.wrappers;

      perSystem = { system, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true; # android-emulator 需要
          };
          overlays = [
            self.overlays.rime-ice
            self.overlays.old-packages
          ];
        };
      };
    };
}
