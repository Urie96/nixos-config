{ self, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    let
      rpi-base = lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          "${self.inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          self.nixosModules.base-image
        ];
        specialArgs = {
          inherit self;
        };
      };
    in
    {
      packages.build-rpi-image = rpi-base.config.system.build.sdImage;
    };
}
