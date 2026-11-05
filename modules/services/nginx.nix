{
  flake.nixosModules.nginx = {
    services.nginx = {
      enable = true;
      clientMaxBodySize = "1G";
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      # recommendedBrotliSettings = true;
      appendHttpConfig = ''
        # http->https
        error_page 497 =307 https://$host:$server_port$request_uri;

        # 局域网白名单。目前没有地方用到 $whitelist；要在鉴权层做同样的事，
        # 用 authelia 的 access_control: { networks = [...]; policy = "bypass"; }
        geo $whitelist {
          default 0;
          192.168.2.0/24 1;
        }
      '';
      defaultSSLListenPort = 8443;
      virtualHosts = {
        "_" = {
          addSSL = true;
          useACMEHost = "lubui.com";
          locations."/".return = 404;
        };
      };
    };
  };
}
