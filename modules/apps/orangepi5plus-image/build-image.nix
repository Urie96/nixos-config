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
      # https://github.com/gnull/nixos-rk3588/tree/main/examples/upstream-opi
      orangepi5plus = lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.nixosModules.base-image
          ./_sdcard.nix
          ./_hardware-configuration.nix
        ];
        specialArgs = {
          inherit self;
        };
      };
    in
    {
      # sdImage 的 out 是一个包含镜像文件的目录（不是可执行程序），
      # 所以用 packages 而不是 apps：nix build .#build-orangepi5plus-image
      packages.build-orangepi5plus-image = orangepi5plus.config.system.build.sdImage;
    };
}
