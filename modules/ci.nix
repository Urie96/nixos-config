{
  self,
  withSystem,
  ...
}:
# flake 输出：`ci.<system>.all` = 该 system 下所有整机配置的 toplevel，
# `ci.<system>.<machine>` = 单台机器的 toplevel。
let
  # 显式列举要进 CI 的整机配置：下面的表就是唯一的 source of truth，
  # 想排除某台机器，删掉对应一行即可（不会自动从 nixosConfigurations 抓全量）。
  nixos = name: self.nixosConfigurations.${name}.config.system.build.toplevel;
  darwin = name: self.darwinConfigurations.${name}.config.system.build.toplevel;
  # system-manager（modules/machines/devbox.nix），本身就是一个 derivation
  systemManager = system: name: self.legacyPackages.${system}.systemConfigs.${name};
  # nix-on-droid（modules/machines/nix-on-droid.nix）
  nixOnDroid =
    name: self.legacyPackages.aarch64-linux.nixOnDroidConfigurations.${name}.activationPackage;

  # mkCi：把该 system 下列出的所有配置收进 `all`，并各自单独暴露一个属性。
  # `nix build .#ci.<system>.all` 一次构建全部，`nix path-info -Sh ./result`
  # 得到整组闭包大小。
  mkCi =
    system: attrs:
    withSystem system (
      { pkgs, ... }:
      attrs
      // {
        all = pkgs.linkFarm "ci-${system}-all" (
          map (name: {
            inherit name;
            path = attrs.${name};
          }) (builtins.attrNames attrs)
        );
      }
    );
in
{
  flake.ci = {
    x86_64-linux = mkCi "x86_64-linux" {
      home-server = nixos "home-server";
      nixos-desktop = nixos "nixos-desktop";
      tencent-cloud-korea = nixos "tencent-cloud-korea";
      devbox = systemManager "x86_64-linux" "devbox";
    };

    aarch64-linux = mkCi "aarch64-linux" {
      orangepi5plus = nixos "orangepi5plus";
      rpi4 = nixos "rpi4";
      nix-on-droid = nixOnDroid "default";
    };

    # nix-darwin 机器；`nix-on-droid` 在这里会直接 throw，
    # `systemConfigs.devbox` 在 darwin 上也 eval 不了，所以不列。
    aarch64-darwin = mkCi "aarch64-darwin" {
      mac-mini = darwin "mac-mini";
      work-macbook = darwin "work-macbook";
    };
  };
}
