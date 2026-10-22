{
  flake.nixosModules.amd = { self, pkgs, ... }: {
    imports = [
      self.inputs.nixos-hardware.nixosModules.common-gpu-amd
      self.inputs.nixos-hardware.nixosModules.common-cpu-amd
      self.inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
      self.inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
      self.inputs.nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    ];

    # nixpkgs 26.11 起内核模块改用 kmodigest 生成单模块签名证书，内核模块聚合
    # （aggregateModules）会把所有外部模块的 .ko.cer 拼进 modules.cer。
    # zenpower 仍用 install(1) 手工装 .ko，不走 Kbuild 的 modules_install，
    # 因此没有 .ko.cer，导致 linux-<ver>-modules 构建失败：
    #   cat: kernel/drivers/hwmon/zenpower/zenpower.ko.cer: No such file or directory
    # 参见 NixOS/nixpkgs#575192，修复见 NixOS/nixpkgs#576565；nixpkgs 合入后可删除。
    boot.kernelPackages = pkgs.linuxPackages.extend (
      _final: prev: {
        zenpower = prev.zenpower.overrideAttrs (_: {
          makeFlags = prev.kernelModuleMakeFlags ++ [
            "KERNEL_BUILD=${prev.kernel.dev}/lib/modules/${prev.kernel.modDirVersion}/build"
            "INSTALL_MOD_PATH=${placeholder "out"}"
            "INSTALL_MOD_DIR=kernel/drivers/hwmon/zenpower"
            "INSTALL_MOD_STRIP=1"
            "DEPMOD=true"
          ];
          installTargets = [ "modules_install" ];
          installFlags = [
            "-C"
            "${prev.kernel.dev}/lib/modules/${prev.kernel.modDirVersion}/build"
            "M=$(PWD)"
          ];
          installPhase = null;
        });
      }
    );

    hardware.graphics.extraPackages = with pkgs; [
      rocmPackages.clr.icd # amd
    ];
  };
}
