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

      environment.systemPackages = ([
        inputs'.clan-core.packages.default
      ])
      ++ (with inputs'.nur-packages.packages; [
        telegram
        wechat
      ]);

      clan.core.networking.targetHost = "root@192.168.2.2";

      homebrew.casks = [
        "calibre"
        "neteasemusic"
      ];
      system.stateVersion = 5;

      nixpkgs.hostPlatform = "aarch64-darwin";
    };
}
