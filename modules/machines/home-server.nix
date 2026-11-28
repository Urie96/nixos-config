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
        router
        singbox-home
        # dae 接管了 singbox-home 原来的全局网关职责（eBPF 透明代理），
        # dnsmasq 给 dae 提供本地 DNS 记录（.lan / *.lubui.com）。
        dae-home
        dnsmasq-local
        # 这台机器也是构建机（x86 leg 的 runner），构建的包也在构建时签名
        nix-signing
        # gitea-runner-home
        nixbot
        # aarch64-linux 派给 orangepi5plus，aarch64-darwin 派给 mac-mini
        nix-builders-client
        # Switch 游戏文件处理工具；prod.keys 的 clan var 在模块里声明
        hacbrewpacklz
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

      # 挂载点本身必须归 root：aria2 / tgdl 的下载目录建在它下面（/mnt/hdd/downloads/*），
      # 由 systemd-tmpfiles 以 root 创建并 chown 给服务用户。systemd-tmpfiles 带
      # CHASE_SAFE 检查，遇到「父目录属于非 root 用户 → 子目录属于 root」会直接拒绝
      # （journal 里是 `Detected unsafe path transition /mnt/hdd (owned by urie) → …`，
      # 结果目录建不出来，tgdl 起服务时报 226/NAMESPACE）。这个 owner 存在盘上，
      # 重新插拔也不会变，用 mkBefore 保证排在生成目录的规则前面。
      # 盘里的现有数据（switch_games 等）不动；urie 在挂载点顶层新建目录要 sudo。
      systemd.tmpfiles.rules = lib.mkBefore [
        "d /mnt/hdd 0755 root root - -"
      ];

      # Use the systemd-boot EFI boot loader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      system.stateVersion = "24.11";

      srvos.detect-hostname-change.enable = false;

      # srvos 默认给所有机器加 console=ttyS0,115200（serial.nix），于是 systemd-getty-generator
      # 为 ttyS0 生成 serial-getty 实例；但这台机器没有真实串口，8250 驱动注册的
      # ttyS0~ttyS3 全是 type=0（PORT_UNKNOWN），agetty 一启动就报「不是终端」并以 1 退出，
      # 被 Restart=always 拉起重启，约每 10s 一次、每天 8000+ 次、日志 4MB/天。
      # 只留 tty0，去掉 cmdline 里的 console=ttyS0（需要重新部署 + 重启才生效）。
      srvos.boot.consoles = [ "tty0" ];
    };
}
