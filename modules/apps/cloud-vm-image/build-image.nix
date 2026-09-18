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
      # https://lantian.pub/article/modify-computer/nixos-low-ram-vps.lantian/
      # https://github.com/nix-community/disko/raw/refs/heads/master/docs/disko-images.md

      # nix shell nixpkgs#qemu -c qemu-system-x86_64 -enable-kvm -m 2G -drive "if=virtio,format=raw,file=./main.raw" \
      #   -nic user,hostfwd=tcp:127.0.0.1:2222-:22 \
      #   -nographic

      # dd之后扩容命令：
      # parted /dev/vda resizepart 3 100%
      # btrfs filesystem resize max /
      x86_bootstrap = lib.nixosSystem {
        inherit system;
        modules = [
          self.inputs.disko.nixosModules.disko
          ./_disko.nix
        ]
        ++ (with self.nixosModules; [
          base-image
          uefi
        ])
        ++ [
          ({
            # linux系统查看内核启动参数：cat /proc/cmdline
            boot.kernelParams = [
              # 让内核启动日志能输出到控制台
              "console=tty0"
              "console=ttyS0,115200n8"
              "net.ifnames=0"
            ];

            # 如果没有这个启动时会卡在等待/dev/disk/by-partuuid/disk-main-root这里
            boot.initrd.availableKernelModules = [
              "virtio_net"
              "virtio_pci"
              "virtio_blk"
              "virtio_scsi"
              "virtio_mmio"
            ];

            # 等 https://github.com/nix-community/disko/pull/1277 合并后可删
            # nixpkgs 的 vmTools 现在要求 `kernel` 是带 `target` 的真实内核，
            # 额外模块要走 `kernelModules`。disko 还在用旧接口（把 aggregateModules 传给 `kernel`），
            # 这里显式给出内核镜像名，绕过 `kernel.target` 的检查。
            disko.imageBuilder.pkgs = pkgs.extend (
              final: prev: {
                vmTools = prev.vmTools.override { kernelImage = "bzImage"; };
              }
            );
          })
        ];
      };
    in
    {
      # diskoImagesScript 的 out 本身就是可执行脚本（不按 bin/ 布局），
      # 所以这里给 program 传它的 store path，而不是直接给 derivation。
      apps.build-cloud-vm-image.program = "${x86_bootstrap.config.system.build.diskoImagesScript}";
    };
}
