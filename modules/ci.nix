{ self, withSystem, ... }:
# flake 输出：`ci.all` = 所有架构、所有整机配置的 toplevel 合集（一个 linkFarm），
# `ci.<machine>` = 单台机器的 toplevel。
let
  nixos = name: self.nixosConfigurations.${name}.config.system.build.toplevel;
  darwin = name: self.darwinConfigurations.${name}.config.system.build.toplevel;
  # system-manager（modules/machines/devbox.nix），本身就是一个 derivation
  systemManager = system: name: self.legacyPackages.${system}.systemConfigs.${name};
  # nix-on-droid（modules/machines/nix-on-droid.nix）
  nixOnDroid =
    name: self.legacyPackages.aarch64-linux.nixOnDroidConfigurations.${name}.activationPackage;

  # 唯一的 source of truth：列出的就是进 CI 的整机配置，想排除某台机器删掉一行即可
  # （不会自动从 nixosConfigurations 抓全量）。这里不按 system 分组：一个扁平表，
  # 谁能构建哪台由 builder 配置决定，而不是由表的结构决定。
  targets = {
    home-server = nixos "home-server";
    nixos-desktop = nixos "nixos-desktop";
    tencent-cloud-korea = nixos "tencent-cloud-korea";
    devbox = systemManager "x86_64-linux" "devbox";

    orangepi5plus = nixos "orangepi5plus";
    rpi4 = nixos "rpi4";
    nix-on-droid = nixOnDroid "default";

    mac-mini = darwin "mac-mini";
    work-macbook = darwin "work-macbook";
  };

  # all 用 x86_64-linux 的 pkgs 生成：它只是一堆指向各架构 toplevel 的符号链接，
  # 自身在本地秒建（preferLocalBuild），被链接的 toplevel 才是真正的构建目标，
  # 跨架构的部分交给 nix.buildMachines 派发（aarch64-linux → orangepi5plus，
  # aarch64-darwin → macmini）。
  #
  # 所以 `nix build .#ci.all` 只能在 x86_64-linux 上跑（也只在 CI / home-server 上用）；
  # 在 darwin 上求值会得到一个 x86_64-linux 的 drv，本机建不了。
  all = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs.linkFarm "ci-all" targets);
in
{
  flake.ci = targets // { inherit all; };
}
