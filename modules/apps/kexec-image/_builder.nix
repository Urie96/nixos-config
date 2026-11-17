# 把某个 image 模块打包成 nixos-anywhere / clan 能吃的 kexec tarball。
#
# 目录结构跟 nix-community/nixos-images 的 kexec-installer 保持一致，
# nixos-anywhere 解包后直接执行 kexec/run：
#
#   kexec/
#   ├── bzImage   内核
#   ├── initrd    内存系统（netboot 的 squashfs store 整个塞在里面）
#   ├── run       在**旧系统**上跑的脚本：收集 ssh 公钥/主机密钥/网络信息，
#   │             以 cpio 追加进 initrd，然后 kexec --load + kexec -e
#   ├── kexec     静态链接的 kexec-tools（旧系统可能啥都没有）
#   └── ip        静态链接的 iproute2
{
  lib,
  system ? "x86_64-linux",
  name,
  image,
}:
let
  cfg = lib.nixosSystem {
    inherit system;
    modules = [ image ];
  };

  pkgs = cfg.pkgs;

  # 静态链接：要在 kexec 之前的任意 Linux 上跑
  iprouteStatic = pkgs.pkgsStatic.iproute2.override { iptables = null; };

  run = pkgs.runCommand "kexec-run" { } ''
    install -D -m 0755 ${./kexec-run.sh} $out
    substituteInPlace $out \
      --replace-fail '@init@' '${cfg.config.system.build.toplevel}/init' \
      --replace-fail '@kernelParams@' '${lib.escapeShellArgs cfg.config.boot.kernelParams}'
  '';
in
pkgs.runCommand "nixos-kexec-${name}-${system}-tarball" { } ''
  mkdir kexec $out
  cp "${cfg.config.system.build.netbootRamdisk}/initrd" kexec/initrd
  cp "${cfg.config.system.build.kernel}/${cfg.config.system.boot.loader.kernelFile}" kexec/bzImage
  cp "${run}" kexec/run
  cp "${pkgs.pkgsStatic.kexec-tools}/bin/kexec" kexec/kexec
  cp "${iprouteStatic}/bin/ip" kexec/ip
  tar -czf $out/nixos-kexec-${name}-${system}.tar.gz kexec
''
