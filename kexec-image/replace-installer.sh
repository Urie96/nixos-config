#!/usr/bin/env bash
# 把一台**已经在 Linux / NixOS installer 里**的机器 kexec 到另一个 kexec tarball。
#
#   ./kexec-image/replace-installer.sh root@1.2.3.4 \
#     "$(nix build .#kexec-image-full --print-out-paths)/nixos-kexec-full-x86_64-linux.tar.gz"
#
# 为什么需要它：`clan machines install/init-hardware-config` 在目标机已经是 installer
# （/etc/os-release 里 VARIANT_ID=installer）时**会跳过 kexec**，所以没法用它从
# 「minimal installer」切到「full installer」；而 Ubuntu 那侧又常常因为内存限制
# 装不下 208MB 的 full initrd。先在 Ubuntu 上用 minimal（179MB）完成第一跳，
# 再从 minimal 里手动切到 full，就绕开了这个限制 —— NixOS 内核没有那堆
# MIGRATE_CMA 页，208MB initrd 的 kexec --load 完全没问题。
#
# 依赖目标机上的 /root/.ssh/authorized_keys（kexec/run 会把它带进新系统）和
# cpio/gzip/setsid/tar（installer 镜像里都有）。
set -euo pipefail

host=${1:?用法: $0 <user@host> <nixos-kexec-*.tar.gz>}
tarball=${2:?用法: $0 <user@host> <nixos-kexec-*.tar.gz>}
dir=${DIR:-/root/kexec-new}
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10)

echo "==> 上传 $(basename "$tarball")（$(du -h "$tarball" | cut -f1)）到 $host:$dir"
scp "${ssh_opts[@]}" "$tarball" "$host:/root/$(basename "$tarball")"

echo "==> 解包并 kexec（连接会断开，约 30-60 秒后重新起来）"
# shellcheck disable=SC2029 # 变量要在远端展开
ssh "${ssh_opts[@]}" "$host" \
  "rm -rf '$dir' && mkdir -p '$dir' && tar -xzf '/root/$(basename "$tarball")' -C '$dir' && \
   cd '$dir' && TMPDIR='$dir' setsid --wait ./kexec/run"

echo "==> 等待新系统回来"
for _ in $(seq 1 30); do
  sleep 5
  if ssh "${ssh_opts[@]}" "$host" true 2>/dev/null; then
    echo "==> 起来了："
    # shellcheck disable=SC2029
    ssh "${ssh_opts[@]}" "$host" \
      'grep VARIANT_ID /etc/os-release; for c in nix nixos-install disko; do printf "%s -> %s\n" "$c" "$(command -v $c || echo 缺失)"; done'
    exit 0
  fi
done
echo "!! 没等到机器回来，去云控制台看串口日志" >&2
exit 1
