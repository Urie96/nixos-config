{ self, ... }:
{
  clan.inventory.machines.nixos-desktop.deploy = {
    targetHost = "root@192.168.2.5";
    buildHost = "urie@home.lubui.com";
  };

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

      my.mainUser.name = "urie";

      environment.systemPackages = with pkgs; [
        kicad
        interactive-html-bom
      ];

      networking.useNetworkd = false; # 因为要使用networkmanager
      networking.firewall.enable = false;
    };

}
