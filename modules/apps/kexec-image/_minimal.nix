# 只做硬件探测的 kexec 镜像：sshd + nixos-facter，没有 nix。
# 体积最小（initrd ≈177MB），用于 `clan machines init-hardware-config`。
{
  imports = [ ./_base.nix ];
}
