{
  flake.nixosModules.adguardhome.services.adguardhome = {
    enable = true;
    mutableSettings = false;
    port = 5300;
    settings = {
      dns = {
        bind_hosts = [ "0.0.0.0" ]; # 局域网可用
        port = 53;
        bootstrap_dns = [ ]; # must define
        upstream_dns = [ "223.5.5.5" ]; # 随便写，会被sing-box拦截
        fallback_dns = [
          # "223.5.5.5"
          # "8.8.8.8"
        ];
      };
      filtering = {
        rewrites = [
          {
            domain = "*.lubui.com";
            answer = "192.168.2.1";
          }
          {
            domain = "mac.mini";
            answer = "192.168.2.2";
          }
          {
            domain = "orangepi.lan";
            answer = "192.168.2.5";
          }
          {
            domain = "router.lan";
            answer = "192.168.2.3";
          }
          {
            domain = "jp.lubui.buzz";
            answer = "13.229.65.246";
          }
          {
            domain = "raspberrypi.lan";
            answer = "192.168.2.7";
          }

        ];
      };
    };
  };
}
