{ self, ... }:
let
  common = {
    nixpkgs = {
      config = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };

      overlays = [ self.overlays.rime-ice ];
    };
  };
in
{
  flake.nixosModules.common = common;
  flake.darwinModules.common = common;
  flake.droidModules.common = common;
}
