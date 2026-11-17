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
      mkImage =
        name: image:
        let
          inherit (self.inputs.nixpkgs) lib;
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
        '';
    in
    {
      # 只对 x86_64-linux 暴露：kexec installer 的用途就是给云主机装 NixOS，
      # 而且 aarch64 上构建要模拟，没必要默认挂进 flake 输出。
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        kexec-image-minimal = mkImage "minimal" ./_base.nix;
        kexec-image-full = mkImage "full" {
          imports = [ ./_base.nix ];

          kexecImage.installerSupport = true;
        };
      };
    };
}
