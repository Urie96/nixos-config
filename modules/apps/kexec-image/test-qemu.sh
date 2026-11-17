#!/usr/bin/env bash
# 在本地 QEMU 里开机验证一个 kexec tarball（不需要真的重启远端机器）。
#
#   ./modules/apps/kexec-image/test-qemu.sh $(nix build .#kexec-image-minimal --print-out-paths)/nixos-kexec-minimal-x86_64-linux.tar.gz
#
# 做的事：解包 → 用 ~/.ssh/*.pub 做一份 authorized_keys 追加进 initrd（等价于
# kexec/run 在旧系统上做的事）→ 起 QEMU（KVM，hostfwd 到 2222）→ 等 ssh →
# 检查 PATH / nixos-facter / 非交互 ssh 的 get-facts 关键项 → 关掉 QEMU。
set -euo pipefail

tarball=${1:?用法: $0 <nixos-kexec-*.tar.gz>}
pubkey=${PUBKEY:-$HOME/.ssh/id_ed25519.pub}
port=${PORT:-2222}
work=$(mktemp -d)
trap 'kill ${qemu_pid:-} 2>/dev/null || true; rm -rf "$work"' EXIT

tar -xzf "$tarball" -C "$work"

# 等价于 kexec/run 里的 append cpio
mkdir -p "$work/ovl/ssh"
chmod 700 "$work/ovl/ssh"
install -m 600 "$pubkey" "$work/ovl/ssh/authorized_keys"
chmod u+w "$work/kexec/initrd"
( cd "$work/ovl" && find . | cpio -o -H newc 2>/dev/null | gzip -9 ) >>"$work/kexec/initrd"

init=$(grep -o 'init="[^"]*"' "$work/kexec/run" | cut -d'"' -f2)

qemu=$(nix build --no-link --print-out-paths nixpkgs#qemu)/bin/qemu-system-x86_64
"$qemu" \
  -enable-kvm -m 1536 -smp 2 \
  -kernel "$work/kexec/bzImage" \
  -initrd "$work/kexec/initrd" \
  -append "init=$init console=ttyS0 loglevel=4 panic=1" \
  -netdev "user,id=n0,hostfwd=tcp::$port-:22" -device virtio-net-pci,netdev=n0 \
  -nographic -no-reboot >"$work/qemu.log" 2>&1 &
qemu_pid=$!

ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5)
for _ in $(seq 1 60); do
  if ssh "${ssh_opts[@]}" -p "$port" root@127.0.0.1 true 2>/dev/null; then
    break
  fi
  sleep 2
done

echo "=== PATH / nixos-facter"
ssh "${ssh_opts[@]}" -p "$port" root@127.0.0.1 \
  'echo PATH=$PATH; command -v nixos-facter; hostname; grep VARIANT_ID /etc/os-release'

echo "=== nixos-facter 能否跑出报告"
ssh "${ssh_opts[@]}" -p "$port" root@127.0.0.1 'nixos-facter | head -c 120'

echo
echo "=== qemu 串口日志（末尾）"
tail -5 "$work/qemu.log"
