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
          ({ my.mainUser.name = "yangrui.0"; })
        ];
      };
    };
}
