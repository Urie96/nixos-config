{ self, ... }:
let
  common = {
    nixpkgs = {
      config = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };

      # 一批固定到 old-nixpkgs 的包（todoman、yazi 等），
      # 名单见 modules/overlays/old-packages。
      overlays = [
        self.overlays.rime-ice
        self.overlays.old-packages
      ];
    };
  };
in
{
  flake.nixosModules.common = common;
  flake.darwinModules.common = common;
}
