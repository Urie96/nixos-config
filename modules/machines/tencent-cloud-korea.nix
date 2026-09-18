{ self, ... }:
{
  clan.inventory.machines.tencent-cloud-korea.deploy = {
    targetHost = "root@43.133.236.247";
    buildHost = "urie@home.lubui.com";
  };

  clan.machines.tencent-cloud-korea = {
    imports = with self.nixosModules; [
      common
      server
      singbox-kr
    ];

    clan.core.deployment.requireExplicitUpdate = true;

    my.mainUser.name = "urie";

    networking.firewall.allowedTCPPorts = [
      8443
      80
      443
    ];

    boot.kernelParams = [
      "console=ttyS0"
      "net.ifnames=0"
    ];

    boot.initrd = {
      compressor = "zstd";
      compressorArgs = [
        "-19"
        "-T0"
      ];
      systemd.enable = true;
    };

    systemd.services."getty@ttyS0".enable = true;

    system.stateVersion = "26.05";
  };
}
