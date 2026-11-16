# 低内存 kexec 引导镜像的公共部分。
#
# 背景：nixos-anywhere 默认的 kexec 镜像是 337MB initrd，而 kexec 的峰值内存
# 开销大约是 initrd 的 2~3 倍（kexec-tools 在用户态读一份 + 内核保留一份，都是
# 不可迁移页）。有些云主机（例如内存被大量 MIGRATE_CMA 页占住的阿里云 ECS）
# 装不下，实测 initrd ≤200MB 可以 load、≥250MB 直接被 OOM killer 干掉。
# 详见 ./README.md。
#
# 这里不用 netboot-minimal / installer profile，避免把 nixpkgs 副本、
# nixos-rebuild（拉 python3）、zfs、perl、vim 等塞进 initrd。
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  kernel = config.boot.kernelPackages.kernel;

  # 只用得上的那些模块。整棵模块树是 144MB（.ko.xz 本身已经压缩，squashfs 也压不动），
  # 是 initrd 里最大的一块。
  wantedModules = [
    # 云主机最常见的一套
    "virtio_pci"
    "virtio_blk"
    "virtio_net"
    "virtio_scsi"
    "virtio_console"
    "virtio_rng"
    "e1000"
    "e1000e"
    "nvme"
    "sd_mod"
    "sr_mod"
    # netboot 的 store 用 squashfs + overlay 挂在 loop 上
    "squashfs"
    "overlay"
    "loop"
    # 目标机的根文件系统
    "ext4"
    "xfs"
    "btrfs"
    "dm_mod"
    # btrfs 的校验和在挂载时通过 crypto API 动态 request_module("crypto-crc32c")
    # 加载，不是 .ko 的 depends，所以 `modprobe --show-depends btrfs` 抓不到它。
    # 漏掉会让 mount btrfs 失败：
    #   BTRFS error (device vda3): error allocating crc32c hash for checksum
    #   BTRFS error (device vda3): open_ctree failed: -2   ← -ENOENT
    # mount(8) 最终报 `fsconfig() failed: No such file or directory`。
    # （xxhash / sha256 在这个内核里是 builtin，只有 blake2b 是模块。）
    "crc32c"
    "blake2b-512"
    # /etc overlay 需要（nixpkgs 26.11 用 erofs 挂 /etc-metadata-image）
    "erofs"
    "autofs4"
    "tun"
    # 网络协议栈相关（缺了 ipv6 时 sshd 会绑 :: 失败/握手卡住）
    "ipv6"
    "af_packet"
    "bridge"
    "stp"
    "llc"
    # 目标盘上可能出现的文件系统
    "vfat"
    "isofs"
    "nls_cp437"
    "nls_iso8859-1"
  ];

  # 只把上面这些模块（含依赖）的 .ko 拷进一个精简的模块树，交给
  # system.modulesTree。stage-1 的 makeModulesClosure 会再从这个树里按依赖
  # 取一次，aggregateModules 会重新跑 depmod 生成 modules.dep。
  minimalKernelModules =
    pkgs.runCommand "kernel-modules-minimal-${kernel.version}"
      {
        nativeBuildInputs = [ pkgs.kmod ];
        preferLocalBuild = true;
      }
      ''
        src=${kernel.modules}/lib/modules/${kernel.version}
        dst=$out/lib/modules/${kernel.version}
        mkdir -p "$dst"
        cp -f "$src"/modules.* "$dst"/ 2>/dev/null || true
        for m in ${lib.escapeShellArgs wantedModules}; do
          modprobe --config no-config -d ${kernel.modules} --set-version ${kernel.version} \
            --show-depends "$m" 2>/dev/null \
          | while read -r cmd mod _; do
              if [ "$cmd" = insmod ] && [ -e "$mod" ]; then
                rel="''${mod##*/lib/modules/${kernel.version}/}"
                mkdir -p "$dst/$(dirname "$rel")"
                cp -f "$mod" "$dst/$rel"
              fi
            done || true
        done
      '';
in
{
  imports = [
    (modulesPath + "/installer/netboot/netboot.nix")
    # 去掉 perl（/etc 改成 overlay，激活脚本不再需要 perl）
    (modulesPath + "/profiles/perlless.nix")
  ];

  options.kexecImage.installerSupport = lib.mkEnableOption ''
    在镜像里带 nix / nixos-install / disko，用于真正装机（`clan machines install`）。
    只做硬件探测（`init-hardware-config`）时不需要，关掉能省 ~30MB initrd。
  '';

  config = lib.mkMerge [
    {
      # 官方 kexec 镜像也用 xz。注意不能加 `compressorArgs = [ "-9" ]`：
      # -9 的 64MB 字典内核解压器不支持，会 panic
      # （Initramfs unpacking failed: Input was encoded with settings that are not
      #  supported by this XZ decoder）
      boot.initrd.compressor = "xz";

      # 从 kexec 前的临时覆盖层里把 ssh 公钥 / 主机密钥 / machine-id
      # 搬进新系统（nix-community/nixos-images 的 restore-remote-access.nix）。
      # nixos-anywhere 的 kexec/run 会把这些文件以 cpio 追加到 initrd 里。
      boot.initrd.systemd.services.restore-state-from-initrd = {
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/sysroot /dev";
        };
        wantedBy = [ "initrd.target" ];
        requiredBy = [ "rw-etc.service" ];
        before = [ "rw-etc.service" ];
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -m 700 -p /sysroot/root/.ssh
          mkdir -m 755 -p /sysroot/etc/ssh
          if [[ -f ssh/authorized_keys ]]; then
            install -m 400 ssh/authorized_keys /sysroot/root/.ssh
          fi
          for f in ssh/ssh_host_*; do
            [ -e "$f" ] && install -m 400 "$f" /sysroot/etc/ssh
          done
          if [[ -f machine-id ]]; then
            cp machine-id /sysroot/etc/machine-id
          fi
        '';
      };

      # nixos-anywhere 在 kexec 之后靠 /etc/os-release 的 VARIANT_ID=installer
      # 判断「确实进了安装环境」，否则报 "Failed to kexec into NixOS installer"。
      system.nixos.variant_id = lib.mkForce "installer";
      system.stateVersion = config.system.nixos.release;
      system.nixos.tags = [ "kexec-minimal" ];

      # ---- 网络 / ssh ----
      networking.hostName = "nixos-installer";
      networking.useDHCP = true;
      networking.firewall.enable = false;
      networking.networkmanager.enable = lib.mkForce false;

      services.openssh.enable = true;
      services.openssh.settings.PermitRootLogin = "yes";
      services.openssh.settings.PasswordAuthentication = false;
      # 非交互 ssh 会话默认不带 /run/current-system/sw/bin，nixos-anywhere 的
      # `command -v nixos-facter` 会找不到，进而去目标机 `nix shell` 拉一遍（国内很慢）
      services.openssh.settings.SetEnv = "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:/run/wrappers/bin";

      # ---- 体积裁剪 ----
      documentation.enable = lib.mkForce false;
      documentation.doc.enable = lib.mkForce false;
      documentation.man.enable = lib.mkForce false;
      documentation.nixos.enable = lib.mkForce false;
      environment.defaultPackages = lib.mkForce [ ];
      # 默认会往 /etc/nix/registry.json 里塞一份 nixpkgs（234MB）
      nix.registry = lib.mkForce { };
      nix.nixPath = lib.mkForce [ ];
      # profiles/base.nix 默认开 zfs，zfs-user 会拉 python3（144MB）
      boot.supportedFilesystems = lib.mkForce {
        ext4 = true;
        vfat = true;
      };
      # 不要 nixos-rebuild / nixos-generate-config（python3）
      system.disableInstallerTools = lib.mkForce true;
      system.extraDependencies = lib.mkForce [ ];
      system.forbiddenDependenciesRegexes = lib.mkForce [ ];
      # 跟 nixos-images 的 noninteractive 镜像一样的小优化
      systemd.sysusers.enable = true;
      services.userborn.enable = lib.mkForce false;
      services.dbus.implementation = lib.mkForce "broker";
      environment.ldso32 = lib.mkForce null;
      programs.nano.enable = lib.mkForce false;
      security.sudo.enable = lib.mkForce false;
      i18n.defaultLocale = lib.mkForce "C.UTF-8";

      hardware.enableAllHardware = lib.mkForce false;
      hardware.enableRedistributableFirmware = lib.mkForce false;

      # 只带需要的 kernel modules
      system.modulesTree = lib.mkForce [ minimalKernelModules ];
      boot.initrd.allowMissingModules = lib.mkForce true;
      boot.initrd.availableKernelModules = [
        "virtio_pci"
        "virtio_blk"
        "virtio_net"
        "virtio_scsi"
        "virtio_console"
        "nvme"
        "sd_mod"
        "sr_mod"
        "ext4"
        "dm_mod"
      ];

      # 硬件探测用，nixos-anywhere 会优先用它
      environment.systemPackages = [ pkgs.nixos-facter ];
    }

    # 只做硬件探测：不需要 nix 本身（省掉 nix + boost + icu + glib ~100MB）
    (lib.mkIf (!config.kexecImage.installerSupport) {
      nix.enable = lib.mkForce false;
      systemd.services.register-nix-paths.enable = lib.mkForce false;
    })

    # 真正装机：要有 nix（nix copy 到目标 store）、nixos-install、disko
    (lib.mkIf config.kexecImage.installerSupport {
      system.tools.nixos-install.enable = lib.mkForce true;
      environment.systemPackages = [
        pkgs.disko
        pkgs.jq
        pkgs.rsync
      ];
    })
  ];
}
