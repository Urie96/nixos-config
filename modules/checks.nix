{ self, ... }:
# `nix flake check` 对 `nixosConfigurations.*` / `darwinConfigurations.*` 只做 eval（nix
# 源码里的 `checkNixOSConfiguration` 只 force `system.build.toplevel` 的 drvPath），不会真的构建。
#
# 这里把每个「整机目标」翻译成一个 check：check 就是目标的 toplevel（system-manager 是它的
# 顶层 derivation，nix-on-droid 是 `activationPackage`），所以
#   · `nix flake check`               → 构建本机架构在这张表里的全部目标；
#   · `nix flake check --all-systems` → 表里三种架构全构建（aarch64-linux 的两台交给
#                                        `nix.buildMachines` 派发，例如 orangepi5plus）。
# eval 失败、构建失败都会让对应的 check 失败，构建出来的产物顺带进 substituter。
#
# 唯一的 source of truth：下面 `targets` 里列出来的就是会跑 check 的目标。不自动从
# `nixosConfigurations` 之类抓全量，所以想排除某台机器，删掉（或注释掉）那一行就行 ——
# 删掉之后它既不会被 eval 也不会被构建。
{
  perSystem =
    {
      system,
      self',
      ...
    }:
    let
      nixos = name: self.nixosConfigurations.${name}.config.system.build.toplevel;
      darwin = name: self.darwinConfigurations.${name}.config.system.build.toplevel;
      # system-manager 的 `makeSystemConfig` 直接返回 toplevel 这个 derivation 本身
      # （没有 `build.toplevel`，也没有 `config.nixpkgs`）。
      systemManager = name: self'.legacyPackages.systemConfigs.${name};
      nixOnDroid = name: self'.legacyPackages.nixOnDroidConfigurations.${name}.activationPackage;

      # 按架构分组是必须的（`checks.<system>` 只该放本机能构建的目标），
      # 但分组之外就是一条目标一行：名字 = check 名，想加减目标只动这张表。
      # 注意每条都要放在和它 `hostPlatform` 一致的分支里，否则 `nix flake check` 会试图
      # 在本机直接构建别的架构（只有配了远程 builder 派发才可能成功）。
      targets = {
        x86_64-linux = {
          # ali-cloud-light-vmess = nixos "ali-cloud-light-vmess";
          home-server = nixos "home-server";
          nixos-desktop = nixos "nixos-desktop";
          tencent-cloud-korea = nixos "tencent-cloud-korea";
          system-manager-devbox = systemManager "devbox";
        };

        aarch64-linux = {
          orangepi5plus = nixos "orangepi5plus";
          # rpi4 = nixos "rpi4";
          nix-on-droid-default = nixOnDroid "default";
        };

        aarch64-darwin = {
          mac-mini = darwin "mac-mini";
          work-macbook = darwin "work-macbook";
        };
      };
    in
    {
      checks = targets.${system} or { };
    };
}
