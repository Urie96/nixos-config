{
  flake.nixosModules.catppuccin =
    {
      config,
      self,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        self.inputs.catppuccin-nix.nixosModules.catppuccin
      ];

      catppuccin = {
        enable = true;
        autoEnable = true;
        flavor = "mocha";
      };
    };

}
