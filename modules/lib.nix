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
                _module.args.pkgs = lib.mkForce pkgs;
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
            inherit pkgs;
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
