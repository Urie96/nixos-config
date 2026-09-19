{
  clan.inventory.machines.rpi4.deploy = {
    targetHost = "root@192.168.2.7";
    buildHost = "urie@orangepi5plus.lan";
  };

  clan.machines.rpi4 =
    {
      self,
      config,
      lib,
      ...
    }:
    {
      imports = [
        self.inputs.nixos-hardware.nixosModules.raspberry-pi-4
        self.nixosModules.base
      ];

      clan.core.deployment.requireExplicitUpdate = true;

      my.mainUser.name = "urie";

      # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
      boot.loader.grub.enable = false;
      # Enables the generation of /boot/extlinux/extlinux.conf
      boot.loader.generic-extlinux-compatible.enable = true;

      system.stateVersion = "26.11";
    };
}
