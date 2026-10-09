{ self, ... }:
{
  perSystem =
    {
      mkSystemManagerConfig,
      ...
    }:
    {
      legacyPackages.systemConfigs.devbox = mkSystemManagerConfig {
        modules = [
          self.sysModules.full
          self.sysModules.harmonia
          ({
            my.mainUser.name = "yangrui.0";
            home-manager.users."yangrui.0".programs.ssh.settings."code.byted.org" = {
              IdentityFile = "~/.ssh/id_ed25519";
              IdentitiesOnly = "yes";
              User = "git";
            };
          })
        ];
      };
    };
}
