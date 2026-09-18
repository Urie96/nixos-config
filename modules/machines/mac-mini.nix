{ self, ... }:
{
  clan.inventory.machines.mac-mini = {
    machineClass = "darwin";
    deploy.targetHost = "root@192.168.2.2";
  };

  clan.machines.mac-mini =
    { inputs', ... }:
    {
      imports = with self.darwinModules; [
        full
      ];

      system.primaryUser = "urie";

      environment.systemPackages = [
        inputs'.clan-core.packages.default
      ];

      clan.core.networking.targetHost = "root@192.168.2.2";

      homebrew.casks = [
        "telegram"
        "wechat"
        "neteasemusic"
      ];
      system.stateVersion = 5;

      nixpkgs.hostPlatform = "aarch64-darwin";
    };
}
