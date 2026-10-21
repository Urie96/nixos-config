{
  self,
  ...
}:
{
  # system-manager 上的 sops-nix：直接复用 sops-nix 的 NixOS 模块。
  #
  # system-manager 没有 NixOS 的 activation script 机制，配置切换是把 unit 写进
  # /etc/systemd/system 再 restart sysinit-reactivation.target。sops-nix 本身有一条
  # 纯 systemd 的实现（sops.useSystemdActivation → sops-install-secrets.service），
  # system-manager 自带的兼容层 nix/modules/upstream/sops-nix.nix 会把这条路径打开，
  # 并补齐 sops-nix 在 NixOS 上依赖、system-manager 没有的东西
  # （system.activationScripts 占位、把 unit 排序重指到 userborn 等）。
  # 所以这里只需要 import，不需要自己写安装 secrets 的逻辑。
  #
  # 注意：system-manager 不管理 services.openssh，sops-nix 猜不到 host key，
  # 消费方必须自己设置 sops.age.keyFile / sops.age.sshKeyPaths。
  # 文档：system-manager 仓库 docs/site/how-to/manage-secrets.md
  flake.sysModules.sops = {
    imports = [ self.inputs.sops-nix.nixosModules.sops ];
  };
}
