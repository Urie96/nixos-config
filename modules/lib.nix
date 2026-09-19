{
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      self',
      inputs',
      ...
    }:
    {
      _module.args = {
        mkSystemManagerConfig =
          {
            modules ? [ ],
          }:
          self.inputs.system-manager.lib.makeSystemConfig {
            modules = [
              {
                nixpkgs.hostPlatform = system;
              }
            ]
            ++ modules;

            specialArgs = {
              inherit
                self
                inputs'
                self'
                ;
            };
          };

        mkDroidConfig =
          {
            modules ? [ ],
          }:
          self.inputs.nix-on-droid.lib.nixOnDroidConfiguration {
            modules = modules;
            extraSpecialArgs = {
              inherit
                self
                inputs'
                self'
                ;
            };
          };
      };
    };

}
