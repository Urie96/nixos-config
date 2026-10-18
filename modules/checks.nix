{ self, ... }:
{
  # nix flake check 原生只校验 `nixosConfigurations.<name>.config.system.build.toplevel`
  # （nix 源码里 `checkNixOSConfiguration`，且不按 system 过滤，6 台机器全评估）。
  #
  # 其它几类「整机配置」它一概不看：
  #   · `darwinConfigurations.*`  → 在 nix 里属于 "Known but unchecked community attribute"，
  #                                  连求值都不会发生；
  #   · `legacyPackages.*.systemConfigs.*`（system-manager）→ 只检查 system 名字，不 force；
  #   · `legacyPackages.*.nixOnDroidConfigurations.*`（nix-on-droid）→ 同上。
  #
  # 这里把它们翻译成 checks：把目标配置的 drvPath 写进一个文本文件。
  # `nix flake check` 求值 checks 时必然 force 这个字符串，所以配置 eval 失败 = 检查失败；
  # 而真正的构建只是 writeText（不构建目标系统，跨架构也不会触发 qemu）。
  # 所以：`nix flake check --no-build` 就是「所有整机配置的 eval 冒烟测试」。
  perSystem =
    { pkgs, lib, system, ... }:
    let
      # 只做 eval 的检查：把目标配置的 drvPath 写进一个文本文件。
      # unsafeDiscardStringContext 是必须的，否则插值会把目标 .drv 变成构建依赖。
      evalOnly =
        name: drv:
        pkgs.writeText "check-${name}-eval" (builtins.unsafeDiscardStringContext drv.drvPath);

      legacy = self.legacyPackages.${system} or { };

      darwinChecks = lib.mapAttrs' (
        name: cfg: lib.nameValuePair "darwin-${name}-eval" (evalOnly "darwin-${name}" cfg.system)
      ) (self.darwinConfigurations or { });

      # system-manager 只支持 Linux 宿主（aarch64-darwin 上连 pkgs 都 eval 不了）
      systemManagerChecks = lib.mapAttrs' (
        name: drv:
        lib.nameValuePair "system-manager-${name}-eval" (evalOnly "system-manager-${name}" drv)
      ) (legacy.systemConfigs or { });

      # nix-on-droid 自己会 throw "aarch64-darwin is not supported"
      droidChecks = lib.mapAttrs' (
        name: cfg:
        lib.nameValuePair "nix-on-droid-${name}-eval" (
          evalOnly "nix-on-droid-${name}" cfg.activationPackage
        )
      ) (legacy.nixOnDroidConfigurations or { });
    in
    {
      checks =
        darwinChecks
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (systemManagerChecks // droidChecks);
    };
}
