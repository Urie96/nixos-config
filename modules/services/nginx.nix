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
        # telegraf 的 nginx 输入（modules/services/monitoring/telegraf.nix）靠
        # ngx_http_stub_status_module 读连接数/请求数。单独开一个只监听回环的 vhost，
        # 不走 80/8443 上的对外站点，也就不需要 allow/deny 兜底。
        # 端口用 9113（nginx-prometheus-exporter 的老习惯），本机没有别的服务占它。
        nginx-status = {
          listen = [
            {
              addr = "127.0.0.1";
              port = 9113;
            }
          ];
          locations."/nginx_status" = {
            extraConfig = ''
              stub_status;
              access_log off;
            '';
          };
        };
        "_" = {
          addSSL = true;
          useACMEHost = "lubui.com";
          locations."/".return = 404;
        };
      };
    };
  };
}
