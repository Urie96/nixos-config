{ self, lib, ... }:
{

  clan.inventory.machines.ali-cloud-light-vmess.deploy = {
    targetHost = "root@47.76.155.157";
    buildHost = "urie@home.lubui.com";
  };

  clan.machines.ali-cloud-light-vmess = {
    imports = with self.nixosModules; [
      common
      server
      singbox-hk
    ];

    clan.core.deployment.requireExplicitUpdate = true;

    my.mainUser.name = "urie";

    networking.firewall.allowedTCPPorts = [
      8443
      80
      443
    ];

    zramSwap.enable = lib.mkForce true;

    boot.loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "/dev/vda";
        # GRUB embeds into the MBR gap (EF02 partition) + ESP
        forceInstall = true;
      };
      systemd-boot.enable = lib.mkForce false;
    };

    system.stateVersion = "26.05";
  };
}
