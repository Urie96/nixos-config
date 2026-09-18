{
  flake.nixosModules.uefi =
    { lib, ... }:
    {
      boot.loader.grub.efiSupport = lib.mkDefault true;
      boot.loader.grub.efiInstallAsRemovable = lib.mkDefault true;
    };
}
