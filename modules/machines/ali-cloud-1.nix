{ self, lib, ... }:
{

  clan.inventory.machines.ali-cloud-1.deploy.targetHost = "root@123.57.10.215";

  clan.machines.ali-cloud-1 = {
    imports = with self.nixosModules; [
      common
      server
      base
    ];

    nix.settings.substituters = lib.mkForce [
      "https://mirrors.ustc.edu.cn/nix-channels/store?priority=1"
      "https://cache.numtide.com?priority=2"
      "https://cache.lubui.com:8443?priority=3"
      "https://cache.nixos.org/"
    ];

    my.mainUser.name = "urie";

    networking.firewall.allowedTCPPorts = [
      8443
      80
      443
    ];

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 10d";
    };
  };
}
