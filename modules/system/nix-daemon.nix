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
        # harmonia（cache.lubui.com）的缓存 key：它给 narinfo 签名。
        "cache.lubui.com-2:tfGYA7ZOj7ubsmDDpe4q5n4jl58lsbtOa0N5QMHt1dY="
        # 构建签名 key：构建机（home-server / orangepi5plus / mac-mini）的 nix daemon
        # 用它给本机构建的包签名（模块 modules/system/nix-signing.nix），
        # home-server 导入这些包、其它机器替用这些路径时都靠它过 require-sigs。
        "cache.lubui.com-1:sOTVoQUdzu6FAIBD8bqWVWtMRdkr3LSHRMpw4ggKVFA="
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

  flake.sysModules.nix-daemon =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [ nixCommon ];

      nix = {
        enable = lib.mkDefault true;

        settings.trusted-users = [
          config.my.mainUser.name
          "root"
        ];
      };
    };
}
