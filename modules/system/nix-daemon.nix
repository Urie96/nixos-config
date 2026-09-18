let
  nixCommon =
    {
      config,
      pkgs,
      self,
      ...
    }:
    {
      nix.channel.enable = false;
      nix.package = pkgs.nixVersions.latest;
      nix.nixPath = [ "nixpkgs=${self.inputs.nixpkgs}" ];

      nix.settings.substituters = [
        "https://cache.lubui.com:8443"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://cache.numtide.com"
      ];
      nix.settings.trusted-substituters = [
        "https://cache.lubui.com:8443"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://cache.numtide.com"
      ];
      nix.settings.trusted-public-keys = [
        "cache.lubui.com-2:tfGYA7ZOj7ubsmDDpe4q5n4jl58lsbtOa0N5QMHt1dY="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
in
{
  flake.nixosModules.nix-daemon = {
    imports = [ nixCommon ];
    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 10d";
      };

      settings = {
        # for nix-direnv
        keep-outputs = true;
        keep-derivations = true;

        trusted-users = [
          "@wheel"
          "root"
        ];

        fallback = true;
        warn-dirty = false;
        auto-optimise-store = true;
      };
    };
  };

  flake.darwinModules.nix-daemon =
    {
      config,
      ...
    }:
    {
      imports = [ nixCommon ];

      nix = {
        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };

        settings = {
          use-xdg-base-directories = true;
          trusted-users = [
            config.system.primaryUser
          ];
        };
      };
    };

  flake.droidModules.nix-daemon = { self, ... }: {
    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';

    nix.registry.nixpkgs.flake = self.inputs.nixpkgs;
  };
}
