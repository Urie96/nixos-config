{ self, lib, ... }:
let
  common = {
    nixpkgs = {
      config = {
        allowUnfree = true;
        android_sdk.accept_license = true;

        # zen-browser 用的 immersive-translate（来自 firefox-addons）在 meta 里既标了
        # 非自由许可，又标了 knownVulnerabilities，所以 allowUnfree 之后还会被 insecure
        # 检查拒掉。用谓词而不是 permittedInsecurePackages（那里要写死 name-version，
        # flake 更新换版本号就得跟着改）。
        allowInsecurePredicate = pkg: lib.hasPrefix "immersive-translate-" pkg.name;
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
