{
  config,
  lib,
  pkgs,
  inputs',
  ...
}:
{
  services.sing-box =
    let
      nur = inputs'.nur-packages.packages;

      sing-box-hk = config.clan.core.vars.generators.sing-box-hk.files;
      sing-box-kr = config.clan.core.vars.generators.sing-box-kr.files;
      sing-box-kr-reality = config.clan.core.vars.generators.sing-box-kr-reality.files;
      sing-box-kr-hysteria2 = config.clan.core.vars.generators.sing-box-kr-hysteria2.files;
    in
    {
      enable = true;
      package = nur.sing-box;
      settings = {
        experimental = {
          cache_file = {
            enabled = true;
            path = "cache.db";
            store_dns = true;
          };
          clash_api = {
            external_controller = "127.0.0.1:9092";
            secret._secret = config.clan.core.vars.generators.clash_api.files.secret.path;
          };
        };
        inbounds = [
          {
            tag = "tun-in";
            type = "tun";
            address = [
              "192.168.3.1/24"
              "fdfe:dcba:9876::1/126"
            ];
            auto_route = true;
            auto_redirect = true;
            interface_name = "tun0";
            strict_route = true;
          }
          # {
          #   tag = "mixed-in";
          #   type = "mixed";
          #   listen = "127.0.0.1";
          #   listen_port = 3128;
          #   set_system_proxy = false;
          # }
        ];
        log = {
          disabled = false;
          level = "error";
          timestamp = true;
        };
        ntp = {
          enabled = true;
          server = "time.apple.com";
        };
        # 节点定义在 _client-outbounds.nix，Android 订阅复用同一份。
        # 仓库里没有 vless-hk（HK 只有 vmess），唯一的 VLESS 节点是 KR 的 REALITY。
        outbounds = import ./_client-outbounds.nix {
          inherit sing-box-hk sing-box-kr sing-box-kr-reality sing-box-kr-hysteria2;
          default = "vless-kr-reality";
        };
        dns = {
          reverse_mapping = true; # 后续从ip反映射回域名从而实现域名路由规则
          strategy = "ipv4_only"; # 阿里云轻量服务器不支持ipv6
          rules = [
            {
              domain = [
                "www.lubui.com"
                "huyue.lubui.com"
                "any.lubui.com"
                "any.home.lubui.com"
              ];
              action = "route";
              server = "alidns";
            }
            {
              domain_suffix = [ ".lubui.com" ];
              action = "predefined";
              rcode = "NOERROR";
              answer = [ "*.lubui.com. 300 IN A 192.168.1.7" ];
            }
            (
              let
                localHosts = {
                  "macmini.lan" = "192.168.2.2";
                  "router.lan" = "192.168.2.3";
                  "rpi.lan" = "192.168.2.7";
                  "kindle.lan" = "192.168.2.9";
                  "termux.lan" = "192.168.2.6";

                  # clan
                  "home-server.lan" = "192.168.2.1";
                  "nixos-desktop.lan" = "192.168.2.5";
                  "orangepi5plus.lan" = "192.168.2.11";
                  "ali-cloud-light-vmess.lan" = "47.76.155.157";
                };
              in
              {
                domain = builtins.attrNames localHosts;
                action = "predefined";
                rcode = "NOERROR";
                answer = lib.mapAttrsToList (host: ip: "${host}. 300 IN A ${ip}") localHosts;
              }
            )
            {
              action = "evaluate";
              server = "alidns";
            }
            {
              action = "reject";
              no_drop = true;
              rule_set = [ "geosite-category-ads-all" ];
            }
            {
              invert = true;
              rule_set = [
                "geosite-cn"
                "geosite-steam@cn"
              ];
              action = "route";
              server = "dns-proxy";
            }
          ];
          final = "alidns";
          servers = [
            {
              tag = "dns-proxy";
              type = "tls";
              server = "8.8.8.8";
              detour = "proxy-out";
            }
            {
              tag = "alidns";
              type = "udp";
              server = "223.5.5.5";
            }
          ];
        };
        route = {
          auto_detect_interface = true;
          rule_set =
            let
              mkGeoSite = name: {
                tag = name;
                type = "local";
                format = "binary";
                path = "${pkgs.sing-geosite}/share/sing-box/rule-set/${name}.srs";
              };
              mkGeoIP = name: {
                tag = name;
                type = "local";
                format = "binary";
                path = "${pkgs.sing-geoip}/share/sing-box/rule-set/${name}.srs";
              };
            in
            [
              (mkGeoIP "geoip-cn")
              (mkGeoSite "geosite-cn")
              # (mkGeoSite "geosite-geolocation-!cn")
              (mkGeoSite "geosite-steam@cn")
              (mkGeoSite "geosite-category-ads-all")
              (mkGeoSite "geosite-category-ai-!cn")
              {
                type = "inline";
                tag = "geosite-direct-extra";
                rules = [
                  {
                    domain = [
                      # "cache.nixos.org"
                      "ddns.oray.com"
                      "https://ip.3322.net"
                      "addons.mozilla.org"
                    ];
                  }
                ];
              }
            ];
          rules = [
            {
              action = "sniff";
            }
            {
              process_name = [ "ddns-updater" ]; # ddns获取ip不要走代理
              action = "route";
              outbound = "direct-out";
            }
            {
              protocol = "dns";
              action = "hijack-dns";
            }
            {
              ip_is_private = true;
              action = "route";
              outbound = "direct-out";
            }
            {
              ip_cidr = [
                "${sing-box-hk.remote_ip.value}/32"
                "${sing-box-kr.remote_ip.value}/32"
              ];
              action = "route";
              outbound = "direct-out";
            }
            {
              rule_set = [ "geosite-direct-extra" ];
              action = "route";
              outbound = "direct-out";
            }
            {
              rule_set = [ "geoip-cn" ];
              action = "route";
              outbound = "direct-out";
            }
            {
              rule_set = [
                "geosite-steam@cn"
                "geosite-cn"
              ];
              action = "route";
              outbound = "direct-out";
            }
            # {
            #   rule_set = [
            #     "geosite-category-ai-!cn"
            #   ];
            #   action = "route";
            #   outbound = "vmess-sg"; # 国外AI不让中国用
            # }
          ];
          final = "proxy-out";
          default_domain_resolver.server = "alidns";
        };
      };
    };

  clan.core.vars.generators.clash_api = {
    files.secret.owner = "sing-box";
    files.nginx_set_secret.owner = "nginx";
    runtimeInputs = with pkgs; [ openssl ];
    script = ''
      openssl rand -hex 32 >$out/secret
      echo "set \$clash_api_secret \"$(cat $out/secret)\";" >$out/nginx_set_secret
    '';
  };

  services.nginx.virtualHosts."singbox.lubui.com" = {
    addSSL = true;
    useACMEHost = "lubui.com";

    extraConfig = config.my.authelia.nginxForwardAuth;

    locations = {
      "= /redirect" = {
        priority = 10;
        extraConfig = ''
          # 每次请求顺手续期 authelia 的 session cookie
          auth_request_set $cookie $upstream_http_set_cookie;
          add_header Set-Cookie $cookie;

          try_files _ @redirect;
        '';
      };
      "@redirect" = {
        extraConfig = ''
          include ${config.clan.core.vars.generators.clash_api.files.nginx_set_secret.path};
          return 302 /ui/?hostname=$scheme://$host&port=$server_port&secret=$clash_api_secret;
        '';
      };
      "/ui/" = {
        priority = 100;
        alias =
          let
            yacd = pkgs.fetchzip {
              url = "https://github.com/haishanh/yacd/releases/download/v0.3.8/yacd.tar.xz";
              hash = "sha256-YrqBRRyKtIKAzPTNp6YfTC8oGI4WTqQ1FohcaubD8XM=";
            };
          in
          "${yacd}/"; # 尾部/至关重要
        tryFiles = "$uri $uri/ /index.html";
        # index = "index.html index.htm";
      };
      "/" = {
        priority = 1000;
        proxyPass = "http://${config.services.sing-box.settings.experimental.clash_api.external_controller}";
        proxyWebsockets = true;
      };
      "/authelia" = {
        priority = 11;
        extraConfig = config.my.authelia.nginxVerifyLocation;
      };
    };
  };
}
