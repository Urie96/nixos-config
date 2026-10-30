{ self, ... }:
{
  clan.inventory.machines.nixos-desktop.deploy.targetHost = "root@192.168.2.5";

  clan.machines.nixos-desktop =
    {
      pkgs,
      ...
    }:
    {
      imports = with self.nixosModules; [
        amd
        full
        desktop
        steam
      ];

      clan.core.deployment.requireExplicitUpdate = true;

      my.mainUser.name = "urie";
      my.homeNetwork = true;

      environment.systemPackages = with pkgs; [
        kicad
        interactive-html-bom
      ];

      networking.useNetworkd = false; # 因为要使用networkmanager
      networking.firewall.enable = false;
    };

}
