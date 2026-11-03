{ self, ... }: {
  flake.nixosModules.server = {
    imports = [
      self.inputs.srvos.nixosModules.server
    ];
  };
}
