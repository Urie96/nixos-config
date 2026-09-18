{
  flake.nixosModules.amd = { self, pkgs, ... }: {
    imports = [
      self.inputs.nixos-hardware.nixosModules.common-gpu-amd
      self.inputs.nixos-hardware.nixosModules.common-cpu-amd
      self.inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
      self.inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
      self.inputs.nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    ];

    hardware.graphics.extraPackages = with pkgs; [
      rocmPackages.clr.icd # amd
    ];
  };
}
