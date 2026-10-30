{ self, ... }:
# `nix flake check` 对 `nixosConfigurations.*` 只做 eval（nix 源码里的
# `checkNixOSConfiguration` 只 force `system.build.toplevel` 的 drvPath），不会真的构建。
#
# 这里把每台机器翻译成一个 check：check 就是该机器的 `toplevel` 本身，所以
#   · `nix flake check`               → 构建本机架构的机器；
#   · `nix flake check --all-systems` → 6 台全构建（aarch64-linux 的两台交给
#                                        `nix.buildMachines` 派发，例如 orangepi5plus）。
# eval 失败、构建失败都会让对应的 check 失败，构建出来的产物顺带进 substituter。
#
# 机器清单不在这里维护：按 `hostPlatform.system` 从 `self.nixosConfigurations` 推导，
# 加一台机器就自动多一个 check，也不会出现「清单忘改」的漏测。
{
  perSystem =
    { system, lib, ... }:
    let
      checksFor =
        target:
        lib.mapAttrs' (name: cfg: lib.nameValuePair name cfg.config.system.build.toplevel) (
          lib.filterAttrs (_: cfg: cfg.config.nixpkgs.hostPlatform.system == target) self.nixosConfigurations
        );
    in
    {
      checks = checksFor system;
    };
}
