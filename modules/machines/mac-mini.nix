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
      ];

      system.primaryUser = "urie";

      environment.systemPackages = ([
        inputs'.clan-core.packages.default
      ]);

      clan.core.networking.targetHost = "root@192.168.2.2";

      homebrew.casks = [
        "calibre"
        "wechat"
        "bambu-studio"
        "feishu"
        # "neteasemusic"
      ];
      system.stateVersion = 5;

      nixpkgs.hostPlatform = "aarch64-darwin";
    };
}
