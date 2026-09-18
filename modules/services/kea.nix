{
  clan.nixosModules.kea = {
    systemd.services.kea-dhcp4-server.after = [ "sys-subsystem-net-devices-enp2s0.device" ]; # 等待网卡启动
    services.kea.dhcp4.enable = true;
    services.kea.dhcp4.settings = {
      interfaces-config = {
        dhcp-socket-type = "raw";
        interfaces = [ "enp2s0" ];
        service-sockets-max-retries = 5;
        service-sockets-retry-wait-time = 5000;
      };
      subnet4 = [
        {
          id = 1;
          option-data = [
            {
              data = "192.168.2.1";
              name = "routers";
            }
            {
              data = "223.5.5.5"; # sing-box拦截即可，这里写一个真实的dns地址，避免sing-box不可用时下游无法dns
              name = "domain-name-servers";
            }
          ];
          pools = [ { pool = "192.168.2.115 - 192.168.2.199"; } ];
          reservations = [
            {
              hw-address = "14:98:77:5d:f5:56"; # mac mini wifi
              ip-address = "192.168.2.2";
            }
            {
              hw-address = "04:67:61:74:BD:5C"; # mi router
              ip-address = "192.168.2.3";
            }
            {
              hw-address = "68:db:54:f6:ec:fd"; # xiaoxun r1 wifi
              ip-address = "192.168.2.4";
            }
            {
              hw-address = "98:BB:99:48:89:49"; # xiaoxun r2 wifi
              ip-address = "192.168.2.13";
            }
            {
              hw-address = "40:9c:a7:0d:8a:a9"; # nixos-desktop wifi
              ip-address = "192.168.2.5";
            }
            {
              hw-address = "c0:74:2b:ff:64:e3"; # orangepi eth
              ip-address = "192.168.2.11";
            }
            {
              hw-address = "58:43:ab:41:71:0d"; # termux
              ip-address = "192.168.2.6";
            }
            {
              hw-address = "e4:5f:01:50:82:38"; # raspberry pi eth
              ip-address = "192.168.2.7";
            }
            {
              hw-address = "e4:5f:01:50:82:39"; # raspberry pi wifi
              ip-address = "192.168.2.8";
            }
            {
              hw-address = "40:b4:cd:fe:c1:37"; # kindle wifi
              ip-address = "192.168.2.9";
            }
            {
              hw-address = "38:05:25:32:b2:d2"; # nixos-desktop eth
              ip-address = "192.168.2.10";
            }
            {
              hw-address = "9c:cc:1:c6:d0:40"; # sms wifi
              ip-address = "192.168.2.12";
            }
          ];
          subnet = "192.168.2.0/24";
        }
      ];
    };
  };
}
