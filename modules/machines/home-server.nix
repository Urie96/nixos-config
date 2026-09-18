{ self, ... }:
{
  clan.inventory.machines.home-server.deploy.targetHost = "root@home.lubui.com";

  clan.machines.home-server =
    {
      pkgs,
      inputs',
      ...
    }:
    {
      imports = with self.nixosModules; [
        amd
        selfhost
        full
        server
        special-day-notify
        systemd-monitor
        router
        singbox-home
      ];

      my.mainUser.name = "urie";

      environment.systemPackages = with pkgs; [
        immich-cli
        inputs'.clan-core.packages.default
      ];

      services.btrfs.autoScrub.enable = true;

      # Use the systemd-boot EFI boot loader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      system.stateVersion = "24.11";

      ###### Qemu编译arm  ######
      # Register binfmt_misc handlers for aarch64 on x86_64
      # This allows running aarch64 binaries natively on x86_64
      boot.binfmt.emulatedSystems = [
        "aarch64-linux"
      ];

      # Add aarch64-linux as an extra platform for building
      nix.settings = {
        extra-platforms = [
          "aarch64-linux"
        ];
      };

      srvos.detect-hostname-change.enable = false;
    };
}
