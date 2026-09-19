{
  clan.inventory.machines.rpi4.deploy = {
    targetHost = "root@192.168.2.7";
    buildHost = "urie@orangepi5plus.lan";
  };

  clan.machines.rpi4 =
    {
      self,
      pkgs,
      ...
    }:
    {
      imports = [
        self.inputs.nixos-hardware.nixosModules.raspberry-pi-4
        self.nixosModules.base
      ];

      clan.core.deployment.requireExplicitUpdate = true;

      my.mainUser.name = "urie";

      networking.useNetworkd = true;
      networking.wireless.enable = false;
      networking.wireless.iwd.enable = true;

      # workaround for https://github.com/NixOS/nixos-hardware/commit/c8f766fd11c8b0a9832b6ca1819de74fbfee3d73
      # the Raspberry Pi kernel is about to be removed from nixpkgs, so the aforementioned commit adds
      # a custom derivation that builds it from scratch. Since nixos-hardware does not have a binary
      # cache is causes a kernel rebuild on this machine, which takes very long.
      # See also https://github.com/NixOS/nixos-hardware/issues/325#issuecomment-4199711155
      # overrides the vendored Raspberry Pi kernel, that is configured by nixos-hardware with
      # the mainline kernel
      boot.kernelPackages = pkgs.linuxPackages;

      # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
      boot.loader.grub.enable = false;
      # Enables the generation of /boot/extlinux/extlinux.conf
      boot.loader.generic-extlinux-compatible.enable = true;

      system.stateVersion = "26.11";
    };
}
