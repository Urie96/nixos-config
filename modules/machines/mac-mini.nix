{ self, ... }:
{
  clan.inventory.machines.mac-mini = {
    machineClass = "darwin";
    deploy.targetHost = "root@192.168.2.2";
  };

  clan.machines.mac-mini =
    {
      config,
      inputs',
      lib,
      pkgs,
      ...
    }:
    {
      imports = with self.darwinModules; [
        full
        gitea-runner-home
        # 本机构建的包自动带缓存签名（harmonia 与客户端都认这把 key）：
        # 推到 home-server 的缓存时才能过 require-sigs 检查。
        nix-signing
        # 作为 home-server 的 aarch64-darwin 远程 builder
        nix-builders-builder
      ];

      my.mainUser.name = "urie";

      environment.systemPackages = ([
        inputs'.clan-core.packages.default
      ]);

      clan.core.networking.targetHost = "root@192.168.2.2";

      # 关掉 kitty 的自定义 shader：custom_shaders 置空后 kitty 不加载任何
      # pipeline（cursor-trail-bubbles 每帧都要多跑一遍全屏 shader）。
      # wrapper 里的默认值是普通定义，这里必须用 mkForce 才能覆盖。
      wrappers.kitty.settings.custom_shaders = lib.mkForce "";

      homebrew.casks = [
        "calibre"
        "wechat"
        "bambu-studio"
        "feishu"
        "moonlight" # 远程控制 nixos-desktop（Sunshine 服务端）
        # "neteasemusic"
      ];
      system.stateVersion = 5;

      nixpkgs.hostPlatform = "aarch64-darwin";
    };
}
