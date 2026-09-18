# AGENTS.md

## 仓库概况

这是一个 Nix Flakes、flake-parts（Dendritic Pattern）和 Clan 管理的多机器配置仓库。`flake.nix` 用 `import-tree ./modules` 自动导入 `modules/` 下的每个 `.nix` 文件，每个文件自带自己的 flake 输出，不需要在 `flake.nix` 里注册。

- 机器定义在 `modules/machines/<machine>.nix`：同一个文件声明 `clan.machines.<machine>`（该机器导入的 module 集合）和 `clan.inventory.machines.<machine>`（部署目标）。机器配置统一写在这里，不要在 `machines/<machine>/` 下新建 `configuration.nix`（clan 也会自动导入它，会造成两份 source of truth）；修改前先确认目标机器，避免把一台机器的变更应用到其他机器。
- `machines/<machine>/` 只放 clan 自动导入的硬件层文件：`hardware-configuration.nix`、`disko.nix`、`facter.json`。路径来自 clan 的约定，不要移动或重命名。
- 可复用配置按用途放在 `modules/` 的子目录里（`common`、`system`、`services`、`features`、`home`、`desktop`、`apps`、`wrappers`、`overlays`），导出成 `flake.<class>Modules.<name>`（如 `flake.nixosModules.common`），再由 `modules/{base,full,server,selfhost}.nix` 组合成机器导入的 module 集合。
- `modules/options/` 声明自定义的 flake 输出和 `my.*` 选项；`modules/machines/{nix-on-droid,devbox}.nix` 用 `perSystem` 定义非 clan 目标（nix-on-droid、system-manager）。

当前主要机器：

- `home-server`：家庭服务器，运行多个 self-hosted 服务。
- `tencent-cloud-korea`：腾讯云上的 sing-box proxy server。
- `ali-cloud-light-vmess`：阿里云轻量服务器上的 sing-box proxy server。
- `orangepi5plus`：RK3588 开发板。
- `rpi4`：树莓派 4。
- `nixos-desktop`：NixOS 桌面主机。
- `work-macbook`：公司使用的 MacBook。
- `mac-mini`：家中使用的 Mac mini 主机。

机器清单以 `clan machines list` 的输出为准。

## 添加或修改 wrapper

先读 [`docs/wrappers.md`](docs/wrappers.md)（目录布局、步骤、通用坑）。要点：`modules/wrappers/` 下的包由 nix-wrapper-modules 包装，导出 `flake.wrappers.<name>`，用 `nix build .#<name>` 验证；最外层必须有「外壳」（缺了会报 `infinite recursion` 且指向 `wlib`）；新文件先 `git add` 才进 flake 源（否则报 `does not provide attribute`）。

## 部署和验证规则

- 不要执行任何会切换或激活系统配置的命令，包括 `nixos-rebuild switch`、`darwin-rebuild switch` 和任何等效的 switch/activate 命令。
- 不要为了验证配置而执行部署。修改完成后如果需要检查是否有错误，使用 Clan 的 build 命令构建目标机器：

  ```bash
  clan machines build <machine>
  ```

  例如检查家庭服务器：

  ```bash
  clan machines build home-server
  ```

- `clan machines build` 默认构建目标机器的 `toplevel`，会进行配置评估和构建，但不会切换正在运行的系统，也不会部署到远程机器。
- 只想进行配置评估、不实际构建产物时，可以使用：

  ```bash
  clan machines build <machine> --dry-run
  ```

- 如果用户明确要求部署，使用 Clan 管理机器更新，而不是 `nixos-rebuild switch`：

  ```bash
  clan machines update <machine>
  ```

## 查看 Clan 源码

本仓库的 flake input 名称是 `clan-core`。可以通过 Nix 获取该 input 在 Nix store 中的源码路径：

```bash
nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.clan-core.outPath'
```

如果需要了解 clan 命令的具体行为，先查看当前版本的帮助：

```bash
clan machines --help
clan machines build --help
clan machines update --help
```

## 查看 nixpkgs 源码和查找模块

本仓库锁定的 nixpkgs 源码路径可以通过 flake input 获取。推荐先解析出 nixpkgs 的路径，再在这个目录内搜索：

```bash
nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath'
```

查找 NixOS 模块时，使用 `rg` 只搜索 nixpkgs 的模块目录。例如查找 Umami 模块：

```bash
rg --files "$nixpkgs_source/nixos/modules" | rg '(^|/)umami(\.nix)?$'
```

不要从整个 `/nix/store` 开始使用 `find` 或 `rg` 递归搜索。先通过 flake 的 `nixpkgs` input 找到源码目录，再把搜索范围限制在 `$nixpkgs_source` 或其子目录中。
