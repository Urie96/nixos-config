# niks3 服务端在非 NixOS 机器（system-manager）上的封装。
#
# 直接用 niks3 仓库自带的 NixOS module（flake input `niks3`，来自
# https://github.com/Mic92/niks3 ），在 system-manager 上评估/运行需要补三处：
#
#   1. ../system/_nixos-compat.nix —— system-manager 没有 system.stateVersion；
#   2. services.postgresql 的 nixpkgs module —— niks3 默认 database.createLocally = true，
#      会往 services.postgresql 里写 ensureDatabases / ensureUsers；
#   3. socket 的 wantedBy —— 上游只挂 sockets.target，而 system-manager 只把
#      multi-user.target / timers.target 映射到 system-manager.target
#      （见 system-manager/nix/modules/systemd.nix 的 substituteTarget）。
{ self, ... }:
{
  flake.sysModules.niks3 =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [
        self.sysModules.postgresql
        self.inputs.niks3.nixosModules.niks3
        self.inputs.niks3.nixosModules.niks3-auto-upload
      ];

      # 注意：本 module 只需要在机器侧给出下面这些（端点和密钥不放在这里）：
      #   services.niks3 = {
      #     enable = true;
      #     s3 = { endpoint = ...; bucket = ...; accessKeyFile = ...; secretKeyFile = ...; };
      #     apiTokenFile = ...;
      #   };
      # 默认 httpAddr = "127.0.0.1:5751"，前端交给别的反代；
      # niks3.nginx.enable 在 system-manager 上也能评估（nginx 和 security/acme
      # 都是内置模块），但需要 security.acme.acceptTerms = true，devbox 上用不到。
      config = {
        # 上游 `wantedBy = [ "sockets.target" ]` 保留（开机会由系统的 basic.target →
        # sockets.target 拉起），这里再补一条 multi-user.target，让 `system-manager
        # activate` 时也能启动：activate 只 `systemctl start system-manager.target`。
        systemd.sockets.niks3.wantedBy = [ "multi-user.target" ];

        # niks3-auto-upload 的 service 是纯 socket 激活、没有 wantedBy，
        # 在一台已经启动的机器上第一次 activate 不会有人拉起这个 socket，
        # 所以这里显式挂到 multi-user.target 上。
        systemd.sockets.niks3-auto-upload = lib.mkIf config.services.niks3-auto-upload.enable {
          wantedBy = [ "multi-user.target" ];
        };

        # 顺带记录两个 system-manager 上的行为差异（都不需要改）：
        # - services.niks3 里的 stopIfChanged = false 在这里是 no-op：nixpkgs 的
        #   systemd-lib 会把它写成 unit 的 X-StopIfChanged=false，而 system-manager
        #   的 engine 只认 X-RestartIfChanged / X-StopOnRemoval。影响为零——
        #   system-manager 只在 unit 的 store path 变化时重启，不会顺带停掉 socket。
        # - 包默认用 niks3 仓库里的 nix/packages/*.nix（和 module 同版本）。
        #   想换成 nixpkgs 的 pkgs.niks3（版本可能更旧）就自己覆盖
        #   services.niks3.package / serverPackage，注意 CLI 参数兼容性。
      };
    };
}
