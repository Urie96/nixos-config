{ self, ... }:
{
  flake.nixosModules.minimal = {
    imports = [
      "${self.inputs.nixpkgs}/nixos/modules/profiles/headless.nix"
      "${self.inputs.nixpkgs}/nixos/modules/profiles/minimal.nix"
    ];
  };
}
