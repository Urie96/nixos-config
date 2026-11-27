{
  # 所有环境的 sshd 都接受 BATON_SOCKET（客户端带上它，baton 才能在远程会话里
  # 复用本机的 socket）。各环境的开关名和落点不一样：
  #   - NixOS：settings.AcceptEnv 渲染成 `AcceptEnv BATON_SOCKET`
  #   - nix-darwin：extraConfig 写进 /etc/ssh/sshd_config.d/100-nix-darwin.conf
  #   - nix-on-droid：self.droidModules.common 里的 droid-openssh 模块把
  #     extraConfig 追加到 /etc/ssh/sshd_config 末尾
  #   - system-manager：用内置的移植版 openssh 模块的 settings.AcceptEnv
  # 导入方式：modules/scene/base.nix（所有机器）和 modules/common/base-image.nix
  # （装机镜像）都 import 了对应的 `sshd`。
  flake.nixosModules.sshd = {
    services.openssh.settings.AcceptEnv = [ "BATON_SOCKET" ];
  };

  flake.darwinModules.sshd = {
    services.openssh.extraConfig = "AcceptEnv BATON_SOCKET";
  };

  flake.droidModules.sshd = {
    services.openssh.extraConfig = "AcceptEnv BATON_SOCKET";
  };

  # system-manager（devbox 这类 Debian 宿主）：system-manager 自己已经把 nixpkgs 的
  # nixos/modules/services/networking/ssh/sshd.nix 移植了一份内置模块
  # （<system-manager>/nix/modules/upstream/nixpkgs/openssh.nix，默认就 import 了，
  # `settings.AcceptEnv` 包含在内），所以这里不能再去 import nixpkgs 的 sshd.nix，
  # 否则两边重复声明 services.openssh.*，求值会报 "already declared"。
  #
  # enable 会让 system-manager 接管 /etc/ssh/sshd_config（并 mask 发行版的
  # ssh.service/ssh.socket，改用 /usr/sbin/sshd 起 ssh-system-manager.service），
  # 不 enable 的话 settings/extraConfig 不会落到任何地方。
  flake.sysModules.sshd = {
    services.openssh = {
      # enable = true;
      settings.AcceptEnv = [ "BATON_SOCKET" ];
    };
  };
}
