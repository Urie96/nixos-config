{
  flake.nixosModules.router =
    { lib, ... }:
    let
      wan.interface = "enp199s0f4u1u2";
      wan.ip = "192.168.1.7";
      lan.interface = "enp2s0";
      lan.ip = "192.168.2.1";
    in
    {

      # srvos 默认关闭 wait-online，导致 network-online.target 在网卡地址就绪前就触发，
      # mosquitto/kea 等绑定具体 IP 的服务开机必失败（Cannot assign requested address）。
      # 这里重新启用，并让 WAN 网卡参与“在线”判定。
      systemd.network.wait-online.enable = lib.mkForce true;
      systemd.network.networks."40-${wan.interface}".extraConfig = ''
        [Link]
        RequiredForOnline=true
      '';

      networking = {
        nameservers = [ "223.5.5.5" ];
        defaultGateway.address = "192.168.1.1";
        hosts = {
          "192.168.1.7" = [ "home.lubui.com" ];
        };
        defaultGateway.interface = wan.interface;
        hostName = "home-server";
        useDHCP = false;
        interfaces = {
          ${wan.interface}.ipv4.addresses = [
            {
              address = wan.ip;
              prefixLength = 24;
            }
          ];
          ${lan.interface}.ipv4.addresses = [
            {
              address = lan.ip;
              prefixLength = 24;
            }
          ];
        };
        # disable the NixOS firewall and enable nftables
        nat.enable = false;
        nftables = {
          enable = true;
          ruleset = ''
            table ip nat {
              # 端口映射: 18443 -> 43.133.236.247:8443
              chain prerouting {
                type nat hook prerouting priority dstnat; policy accept;
                tcp dport 18443 dnat to 43.133.236.247:8443
              }
              chain postrouting {
                type nat hook postrouting priority 100
                oifname ${wan.interface} masquerade
              }
            }
          '';
        };
        firewall = {
          trustedInterfaces = [
            lan.interface
            "tun0"
          ];
          extraReversePathFilterRules = "iifname tun0 accept";
          interfaces.${wan.interface}.allowedTCPPorts = [
            22
            18443
            8443
            8000
            1883
          ];
        };
      };
    };
}
