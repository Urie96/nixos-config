{ self, ... }:
{
  clan.inventory.machines.home-server.deploy.targetHost = "root@home.lubui.com";

  clan.machines.home-server =
    {
      pkgs,
      inputs',
      lib,
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
        # 这台机器也是构建机（x86 leg 的 runner），构建的包也在构建时签名
        nix-signing
        gitea-runner-home
      ];

      my.mainUser.name = "urie";
      my.homeNetwork = true;

      environment.systemPackages = with pkgs; [
        immich-cli
        inputs'.clan-core.packages.default
      ];

      services.btrfs.autoScrub.enable = true;
      nix.gc.automatic = lib.mkForce false;

      # 外挂机械盘（sda1，btrfs label myHDD）上的自用数据子卷（游戏、杂项）。
      # 与 btrbk 的备份目标 @backup 分开，避免被备份清理逻辑牵连；
      # nofail：硬盘没插时不阻塞启动。
      fileSystems."/mnt/hdd" = {
        device = "/dev/disk/by-uuid/fd34c28c-d7bf-435e-a2c5-0875502391b5";
        fsType = "btrfs";
        options = [
          "subvol=@data"
          "nofail"
          "x-systemd.device-timeout=10s"
          "noatime"
        ];
      };

      # Use the systemd-boot EFI boot loader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      system.stateVersion = "24.11";

      ###### Qemu编译arm  ######
      # Register binfmt_misc handlers for aarch64 on x86_64
      # This allows running aarch64 binaries natively on x86_64
      # boot.binfmt.emulatedSystems = [
      #   "aarch64-linux"
      # ];
      #
      # # Add aarch64-linux as an extra platform for building
      # nix.settings = {
      #   extra-platforms = [
      #     "aarch64-linux"
      #   ];
      # };

      srvos.detect-hostname-change.enable = false;
    };
}
