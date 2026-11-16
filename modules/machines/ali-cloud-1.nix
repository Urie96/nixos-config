{ self, lib, ... }:
{

  clan.inventory.machines.ali-cloud-1.deploy.targetHost = "root@123.57.10.215";

  clan.machines.ali-cloud-1 = {
    imports = with self.nixosModules; [
      minimal
      common
      server
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
