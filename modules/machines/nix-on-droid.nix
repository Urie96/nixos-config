{ self, ... }:
{
  perSystem =
    {
      mkDroidConfig,
      pkgs,
      inputs',
      self',
      ...
    }:
    {
      legacyPackages = {
        nixOnDroidConfigurations.default = mkDroidConfig {
          modules = [
            self.droidModules.full
            ({ my.mainUser.name = "nix-on-droid"; })
          ];
        };
      };
    };
}
