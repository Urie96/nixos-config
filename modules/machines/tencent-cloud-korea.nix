{ self, lib, ... }:
{
  clan.inventory.machines.tencent-cloud-korea.deploy.targetHost = "root@43.133.236.247";

  clan.machines.tencent-cloud-korea = {
    imports = with self.nixosModules; [
      common
      server
      singbox-kr
      bbr
    ];

    clan.core.deployment.requireExplicitUpdate = true;

    my.mainUser.name = "urie";

    # 这台只跑 sing-box：8443 = vmess+ws（旧节点），443/tcp = VLESS+REALITY，
    # 443/udp = hysteria2。
    # 22 是 sshd 自己 openFirewall 开的。
    # 注意腾讯云控制台的安全组也要放行 TCP 443 和 UDP 443，光改 iptables 不够。
    networking.firewall.allowedTCPPorts = [
      443
      8443
    ];
    networking.firewall.allowedUDPPorts = [ 443 ];

    # 代理机用不到 mosh，关掉它顺带关掉防火墙上的 UDP 60000-61000
    programs.mosh.enable = lib.mkForce false;

    # 这两台机器没 import modules/system/nix-daemon.nix，srvos 也不开 GC，
    # 轻量云盘（60G）容易被 /nix/store 撑满。
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 10d";
    };

    boot.kernel.sysctl = {
      # OOPS 后自动重启，等人工救援太慢
      "kernel.panic" = 10;
      # 配合 common 里已开的 zramSwap（NixOS 不调 swappiness，默认还是 60）
      "vm.swappiness" = 120;
    };

    boot.kernelParams = [
      "console=ttyS0"
      "net.ifnames=0"
    ];

    boot.initrd = {
      compressor = "zstd";
      compressorArgs = [
        "-19"
        "-T0"
      ];
    };

    systemd.services."getty@ttyS0".enable = true;

    system.stateVersion = "26.05";
  };
}
