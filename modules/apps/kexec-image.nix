# 低内存机器用的 kexec 引导镜像
#
# 给 `clan machines init-hardware-config` / `clan machines install` 提供比官方
# 小得多的 kexec 镜像。官方 `nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz`
# 的 initrd 是 337MB，在某些云主机上 `kexec --load` 会被内核 OOM 杀掉。
#
#   nix build .#kexec-image-minimal   # 只做硬件探测（initrd ≈177MB）
#   nix build .#kexec-image-full      # 带 nix/nixos-install/disko（initrd ≈206MB）
{ self, ... }:
{
  perSystem =
    { system, lib, ... }:
    let
      mkImage =
        name: image:
        import ../../kexec-image/builder.nix {
          inherit (self.inputs.nixpkgs) lib;
          inherit system name image;
        };
    in
    {
      # 只对 x86_64-linux 暴露：kexec installer 的用途就是给云主机装 NixOS，
      # 而且 aarch64 上构建要模拟，没必要默认挂进 flake 输出。
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        kexec-image-minimal = mkImage "minimal" ../../kexec-image/minimal.nix;
        kexec-image-full = mkImage "full" ../../kexec-image/full.nix;
      };
    };
}
