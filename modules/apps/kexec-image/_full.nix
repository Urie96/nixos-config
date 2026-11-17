# 带 nix / nixos-install / disko 的 kexec 镜像，用于真正装机
# （`clan machines install` 的 disko + install 阶段）。initrd ≈206MB，
# 已经贴着 kexec 的内存红线（≤200MB 稳、≥250MB 必然 OOM）。
{
  imports = [ ./_base.nix ];

  kexecImage.installerSupport = true;
}
