{ self, ... }:
{
  clan.inventory.machines.orangepi5plus.deploy.targetHost = "root@192.168.2.11";

  clan.machines.orangepi5plus =
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = with self.nixosModules; [
        full
        basePkgs
      ];

      my.mainUser.name = "urie";

      networking.useNetworkd = true;
      networking.wireless.enable = false;
      networking.wireless.iwd.enable = true;

      virtualisation.waydroid.enable = true;

      networking.interfaces.enP3p49s0.useDHCP = true;

      environment.systemPackages = with pkgs; [
        gitMinimal
        curl
        lm_sensors
        mtdutils
        i2c-tools
      ];

      system.stateVersion = "26.05";

      boot = {
        kernelParams = [
          "rootwait"

          "earlycon" # enable early console, so we can see the boot messages via serial port / HDMI
          "consoleblank=0" # disable console blanking(screen saver)
          "console=ttyS2,1500000" # serial port
          "console=tty1" # HDMI

          "root=UUID=14e19a7b-0ae0-484d-9d54-43bd6fdc20c7"
          "rootfstype=ext4"
        ];
        consoleLogLevel = 7;

        loader = {
          grub.enable = lib.mkForce false;
          generic-extlinux-compatible.enable = lib.mkForce true;
        };
      };

      boot = {
        kernelPackages = pkgs.linuxPackages_latest;
        supportedFilesystems = {
          # Disabled zfs because it limits the range of kernel versions it's
          # compatible with, and makes kernel packages marked as "broken" every now
          # and then (since zfs source has moved out of kernel tree). If you want
          # zfs, change this and try different kernel packages above until build
          # succeeds.
          zfs = lib.mkForce false;
        };
      };
    };
}
