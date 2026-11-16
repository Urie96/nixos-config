{ self, lib, ... }:
{

  clan.inventory.machines.ali-cloud-1.deploy.targetHost = "root@123.57.10.215";

  clan.machines.ali-cloud-1 = {
    imports = with self.nixosModules; [
      common
      server
    ];

    clan.core.deployment.requireExplicitUpdate = true;

    my.mainUser.name = "urie";

    networking.firewall.allowedTCPPorts = [
      8443
      80
      443
    ];

    programs.mosh.enable = lib.mkForce false;

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 10d";
    };

    boot.kernel.sysctl = {
      # OOPS 后自动重启，等人工救援太慢
      "kernel.panic" = 10;
      # 配合 common 里已开的 zramSwap（NixOS 不调 swappiness，默认还是 60）
      "vm.swappiness" = 120;
    };
  };
}
