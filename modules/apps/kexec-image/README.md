# kexec-image

给 `clan machines init-hardware-config` / `clan machines install` 用的**低内存 kexec 引导镜像**。
比官方 `nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz`（initrd 337MB）小一半多，
用于那些装不下官方镜像的机器。

```bash
nix build .#kexec-image-minimal   # 只做硬件探测：sshd + nixos-facter（initrd ≈179MB）
nix build .#kexec-image-full      # 带 nix / nixos-install / disko，用于真正装机（initrd ≈208MB）
```

产物：`result/nixos-kexec-{minimal,full}-x86_64-linux.tar.gz`，目录结构与
[nix-community/nixos-images](https://github.com/nix-community/nixos-images) 的 kexec tarball 一致
（`kexec/{bzImage,initrd,run,kexec,ip}`），nixos-anywhere 可以直接吃。

## 为什么需要它

第一次给 `ali-cloud-1`（阿里云 1.7GB 内存的 ECS）跑 `clan machines init-hardware-config` 时，
kexec 阶段被内核 OOM 杀掉：

```
+ sh -c '/root/kexec/kexec/kexec' --load .../bzImage --initrd=.../initrd ...
Killed
Kexec failed
# dmesg:
Out of memory: Killed process (kexec) ... global_oom
```

原因是这台机器的内存里有很大一块被标成了 `MIGRATE_CMA`（`/proc/zoneinfo` 里
`cma 203264` 页 ≈ 794MB），而 CMA 页只能给**可迁移**分配用，kexec 需要的
不可迁移页拿不到：

```
OOM 瞬间: free 678MB，其中 free_cma 626MB → 非 CMA 只剩 ~52MB
```

kexec 的峰值内存大约是 initrd 的 2~3 倍（kexec-tools 在用户态读一份，内核再保留一份，
都是不可迁移、不可换出的页）。在这台机器上实测的边界：

| initrd 大小 | `kexec --load` |
| --- | --- |
| 1MB / 100MB / 200MB | OK |
| 250MB / 300MB / 337MB（官方） | 被 OOM killer SIGKILL |

加 swap、`drop_caches`、`--mem-max`、`kexec_file_load` 都没用（细节见 AGENTS 之外的聊天记录：
swap 只能换出匿名页，回收 page cache 得到的也只是 movable 页，换不成非 CMA 页）。

所以只能把 initrd 做小。

## 目录内容

| 文件 | 说明 |
| --- | --- |
| `_base.nix` | 两个变体共用的 NixOS 配置：netboot + perlless + 一堆体积裁剪 + 模块树裁剪 + sshd/密钥恢复 |
| `_minimal.nix` | `imports = [ ./_base.nix ]`，不带 nix（探测硬件用） |
| `_full.nix` | `imports = [ ./_base.nix ]` + `kexecImage.installerSupport = true`（装机用） |
| `_builder.nix` | 把上面任一变体打包成 kexec tarball（`lib.nixosSystem` → netbootRamdisk + kernel + 静态 kexec/ip + run 脚本） |
| `kexec-run.sh` | 在**旧系统**上跑的脚本（取自 nixos-images）：收集 ssh 公钥/主机密钥/`ip addr`，追加进 initrd，然后 `kexec --load` + `kexec -e` |
| `test-qemu.sh` | 本地 QEMU 开机自检，不需要真重启远端机器 |
| `replace-installer.sh` | 把一台已经在 installer 里的机器 kexec 到另一个 tarball（见下面「两跳装机」） |

flake 输出在 [`./kexec-image.nix`](./kexec-image.nix)，
只对 `x86_64-linux` 暴露 `packages.kexec-image-{minimal,full}`。

`_` 前缀是给 `import-tree ./modules` 看的：带下划线的文件不会被当成 flake-parts 模块
导入（这里的 `_base/_minimal/_full/_builder` 是 NixOS 模块和打包函数，不是 flake 模块），
和 `modules/apps/cloud-vm-image/` 的约定一致。

## 用法

硬件探测（机器会重启进临时 NixOS，磁盘不动）：

```bash
clan machines init-hardware-config ali-cloud-1 --target-host root@<ip> \
  --backend nixos-facter \
  --kexec "$(nix build .#kexec-image-minimal --print-out-paths)/nixos-kexec-minimal-x86_64-linux.tar.gz"
```

装机（注意同时要 `clan vars generate <machine>`、机器要有 disko 配置）：

```bash
clan machines install ali-cloud-1 --target-host root@<ip> \
  --kexec "$(nix build .#kexec-image-full --print-out-paths)/nixos-kexec-full-x86_64-linux.tar.gz"
```

### 上传很慢怎么办

`--kexec <本地文件>` 时 nixos-anywhere 会用 `cat file | ssh 'cat > …'` 上传；`--kexec <URL>`
时是**目标机自己 wget**。国内 GitHub 直连基本不可用（实测目标机 29KB/s），走
`https://gh-proxy.com/https://github.com/...` 之类的镜像能跑满带宽（实测 1.1MB/s，约等于那台
机器的入站上限）。本仓库的 `machines/ali-cloud-1.nix` 这种云主机入站通常就 ~10Mbps。

## 两跳装机（低内存机器上装机的正确姿势）

`clan machines install` 需要目标机上有 **nix / nixos-install / disko**，只有 `full` 变体有；
但 `full` 的 initrd 是 208MB，在 Ubuntu 那侧可能 load 不上。而 kexec 起来的 NixOS 内核没有
那堆 `MIGRATE_CMA` 页，208MB 完全没问题。所以分两跳：

```bash
# 第 1 跳：Ubuntu → minimal（179MB，能稳定 load）
clan machines init-hardware-config ali-cloud-1 --target-host root@<ip> \
  --kexec "$(nix build .#kexec-image-minimal --print-out-paths)/nixos-kexec-minimal-x86_64-linux.tar.gz"
# （这条命令最后会因为 minimal 里没有 nix 而 exit 127，facter.json 已经生成，无所谓）

# 第 2 跳：minimal installer → full installer（此时内存正常，208MB 无压力）
./modules/apps/kexec-image/replace-installer.sh root@<ip> \
  "$(nix build .#kexec-image-full --print-out-paths)/nixos-kexec-full-x86_64-linux.tar.gz"

# 现在目标机就是带 nix 的 installer 了，clan 会跳过 kexec 直接 disko + install
clan machines install ali-cloud-1
```

为什么第 2 跳不能直接交给 clan：nixos-anywhere 发现目标机已经是 installer
（`VARIANT_ID=installer`）时会把 kexec 阶段直接跳过，所以必须手动跑一次 `kexec/run`。
`replace-installer.sh` 就是干这个的（scp + 解包 + `setsid --wait ./kexec/run` + 等机器回来）。

实测：在 `ali-cloud-1` 的 minimal installer 上 `kexec --load` 208MB initrd 成功
（同一台机器在 Ubuntu 下 250MB 就被 OOM 杀了）。

## 验证

改完镜像先本地开机验一遍，别直接拿去重启生产机器：

```bash
./modules/apps/kexec-image/test-qemu.sh "$(nix build .#kexec-image-minimal --print-out-paths)/nixos-kexec-minimal-x86_64-linux.tar.gz"
```

脚本会：用 `~/.ssh/id_ed25519.pub` 造一份 `authorized_keys` 追加进 initrd（等价于 `kexec/run`
干的事），起 QEMU + hostfwd，等 ssh 起来后检查 `PATH` / `nixos-facter` / `VARIANT_ID=installer`，
最后打印一段 `nixos-facter` 报告。

更贴近真实流程的检查是把 nixos-anywhere 的 `get-facts.sh` 喂给这台机器，期望：

```
isOs=Linux  isArch=x86_64  isNixos=y  isInstaller=y  isRoot=y
hasTar=y  hasCpio=y  hasSetsid=y  hasNixOSFacter=y
```

`get-facts.sh` 在 nixos-anywhere 包里（下面按 clan 实际调用的那份写的）：

```bash
ssh -p 2222 root@127.0.0.1 sh -s < \
  "$(dirname "$(readlink -f "$(command -v nixos-anywhere)")")/get-facts.sh"
```

## 实现要点（也是坑）

1. **kernel modules 是最大的一块**。整棵 `linux-*-modules` 是 144MB，`.ko.xz` 已经是压缩过的、
   squashfs 压不动，直接占掉 initrd 一半。这里只拷贝 `wantedModules` + 依赖（`modprobe --show-depends`），
   `system.modulesTree` 指向这个精简树，`boot.initrd.allowMissingModules = true`。
   - 改模块清单时也会影响 stage-1 能拿到的模块：**漏掉 `ipv6` / `af_packet` 会让 sshd 握手卡在
     "Connection timed out during banner exchange"**（实测），漏 virtio 更直接开不了机。
2. **不要给 xz 加 `-9`**。`boot.initrd.compressorArgs = [ "-9" ]` 会用 64MB 字典，内核解压器不支持，
   开机会 `Initramfs unpacking failed: Input was encoded with settings that are not supported by this XZ
   decoder` + `Kernel panic`。nixpkgs 默认参数（`--check=crc32 --lzma2=dict=512KiB`）就行。
3. **`VARIANT_ID=installer`**（`system.nixos.variant_id`）：nixos-anywhere 在 kexec 之后靠
   `/etc/os-release` 的这个字段判断「确实进了安装环境」，否则报 `Failed to kexec into NixOS installer`。
4. **`restore-state-from-initrd`**：`kexec/run` 会把旧系统的 `ssh/authorized_keys`、`ssh/ssh_host_*`、
   `machine-id` 以 cpio 追加进 initrd；必须有一个 initrd 阶段的 unit 把它们搬到 `/sysroot`，
   否则 kexec 之后新系统里没有你的公钥，ssh 不进不去（nixos-images 的 `restore-remote-access.nix`）。
5. **`openssh.settings.SetEnv = "PATH=…/sw/bin"`**：非交互 ssh 会话默认 PATH 里没有
   `/run/current-system/sw/bin`，nixos-anywhere 的 `command -v nixos-facter` 会失败，转而去目标机
   `nix shell nixpkgs#nixos-facter`（国内很慢）。加上之后就 `hasNixOSFacter=y` 了。
6. **体积裁剪清单**（都在 `_base.nix` 里，带注释）：不塞 nixpkgs 副本（`system.installer.channel.enable`
   / `nix.registry`，−234MB）、`system.disableInstallerTools`（−python3 144MB）、关 zfs、`profiles/perlless.nix`
   （−perl 58MB）、`environment.defaultPackages`、`dbus.implementation = "broker"`、`ldso32 = null`。
   minimal 还额外关掉 `nix` 本体（−boost/icu/glib ≈100MB）。

## 已知限制

- **minimal 变体没有 nix**。nixos-anywhere 在 kexec 之后（`--build-on auto`，clan 不暴露这个参数）会在
  目标机上跑 `nix config show system`，于是整个命令最终 **退出码 127**：
  ```
  bash: line 1: nix: command not found
  Return Code: 127
  ```
  这发生在 `facter.json` 已经生成、`git add` 之后，结果本身没问题；要命令干净退出就用 `full` 变体
  或者临时升内存用官方镜像。
- **`full` 变体的 initrd ≈208MB**，已经贴着上面那条 ~200MB 的红线（这台机器 200MB 能 load，250MB 不能）。
  真装机更稳的做法是临时把实例升到 4GB 内存，用官方镜像。
- 网络只走 DHCP。静态 IP 的机器需要把 nixos-images 的 `networkd.nix` + `restore_routes.py`
  也搬过来（会引入 python，initrd 变大）。
- 只对 `x86_64-linux` 暴露；aarch64 要在 x86 上模拟构建，暂时没接。
