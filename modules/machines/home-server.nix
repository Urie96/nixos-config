{ self, ... }:
{
  clan.inventory.machines.home-server.deploy.targetHost = "root@192.168.1.7";

  clan.machines.home-server =
    {
      config,
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
        nixbot
        # aarch64-linux 派给 orangepi5plus，aarch64-darwin 派给 mac-mini
        nix-builders-client
      ];

      my.mainUser.name = "urie";

      # 一旦显式配置 IdentityFile，ssh 就不再自动加载默认的
      # ~/.ssh/id_rsa、~/.ssh/id_ed25519，所以把它们一并列出，部署 key
      # 放最后当兜底（不设 IdentitiesOnly，agent 里的 key 也照旧可用）。
      home-manager.users.${config.my.mainUser.name}.programs.ssh.settings."*".IdentityFile = [
        "~/.ssh/id_ed25519"
        "~/.ssh/id_rsa"
        # nixbot 部署私钥（modules/services/nixbot.nix 的 nixbot-deploy-secrets/id_ed25519，
        # owner 就是主用户）。各机器 root 的 authorized_keys 里都有它的公钥
        # （modules/common/nixbot-deploy-target.nix），所以拿到私钥就能直接
        # `ssh root@<机器>`。
        config.clan.core.vars.generators.nixbot-deploy-secrets.files."id_ed25519".path
      ];

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

      srvos.detect-hostname-change.enable = false;
    };
}
