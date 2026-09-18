{
  flake.nixosModules.dashy =
    { config, pkgs, ... }:
    let
      dashy = pkgs.callPackage (
        {
          runCommand,
          yq-go,
          dashy-ui,
          settings ? { },
        }:
        if settings == { } then
          dashy-ui
        else
          runCommand "dashy-ui-modified"
            {
              inherit (dashy-ui) pname version meta;
              src = dashy-ui;
              nativeBuildInputs = [ yq-go ];
            }
            ''
              cp -r $src $out
              chmod +w $out
              rm -rf $out/conf.yml
              yq --output-format yml '${builtins.toFile "conf.json" "${builtins.toJSON settings}"}' >$out/conf.yml
            ''
      ) { };
    in
    {
      services.dashy = {
        enable = true;
        package = dashy;
        settings = {
          appConfig = {
            defaultOpeningMethod = "newtab";
            enableServiceWorker = true;
            language = "zh-CN";
            theme = "raspberry-jam";
          };
          pageInfo = {
            description = "我的家庭服务器";
            navLinks = [
              {
                path = "/";
                target = "sametab";
                title = "Home";
              }
              {
                path = "https://github.com/urie96";
                title = "GitHub";
              }
            ];
            title = "Dashy";
          };
          sections = [
            {
              appConfig = {
                enableFontAwesome = false;
              };
              displayData = {
                collapsed = false;
                cols = 2;
                itemSize = "large";
              };
              items = [
                {
                  description = "照片管理";
                  icon = "https://immich.lubui.com:8443/apple-icon-180.png";
                  title = "Immich";
                  url = "https://immich.lubui.com:8443";
                }
                {
                  description = "多网盘挂载文件列表";
                  icon = "https://doc.oplist.org/favicon.svg";
                  title = "OpenList";
                  url = "https://openlist.lubui.com:8443";
                }
                {
                  description = "服务可用性监控";
                  icon = "https://uptime.lubui.com:8443/icon.svg";
                  title = "Uptime Kuma";
                  url = "https://uptime.lubui.com:8443";
                }
                {
                  description = "通知推送服务";
                  icon = "https://gotify.lubui.com:8443/static/defaultapp.png";
                  title = "Gotify";
                  url = "https://gotify.lubui.com:8443";
                }
                {
                  description = "音乐服务";
                  icon = "https://music.lubui.com:8443/app/android-chrome-192x192.png";
                  title = "Navidrome";
                  url = "https://music.lubui.com:8443";
                }
                {
                  description = "密码管理";
                  icon = "https://pw.lubui.com:8443/images/safari-pinned-tab.svg";
                  title = "Vaultwarden";
                  url = "https://pw.lubui.com:8443";
                }
                {
                  description = "信息流聚合";
                  icon = "https://rss.lubui.com:8443/themes/icons/favicon-256.png";
                  title = "FreshRSS";
                  url = "https://rss.lubui.com:8443";
                }
                {
                  description = "多协议下载器";
                  icon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/github-light.png";
                  title = "Aria2";
                  url = "https://aria.lubui.com:8443/redirect";
                }
                {
                  title = "SingBox";
                  description = "网络代理";
                  icon = "https://sing-box.sagernet.org/assets/icon.svg";
                  url = "https://singbox.lubui.com:8443/redirect";
                }
                {
                  title = "Jellyfin";
                  description = "媒体服务器";
                  icon = "https://jellyfin.lubui.com:8443/web/f5bbb798cb2c65908633.png";
                  url = "https://jellyfin.lubui.com:8443";
                }
                {
                  title = "LiteLLM";
                  description = "聚合大模型 API";
                  icon = "https://fastapi.tiangolo.com/img/favicon.png";
                  url = "https://openai.lubui.com:8443";
                }
                {
                  title = "Love Yue";
                  description = "在一起纪念";
                  icon = "https://huyue-src.lubui.com:8443/favicon.svg";
                  url = "https://huyue-src.lubui.com:8443/";
                }
                {
                  title = "Code Notes";
                  description = "我的笔记";
                  icon = "https://blog.lubui.com:8443/favicon.svg";
                  url = "https://blog.lubui.com:8443";
                }
                {
                  title = "HackBook";
                  description = "程序员专栏";
                  icon = "https://book.lubui.com:8443/favicon.svg";
                  url = "https://book.lubui.com:8443";
                }
                {
                  title = "Node Red";
                  description = "物联网自动化开发工具";
                  icon = "https://nodered.lubui.com:8443/favicon.ico";
                  url = "https://nodered.lubui.com:8443";
                }
                {
                  title = "Home Assistant";
                  description = "智能家居自动化平台";
                  icon = "https://hass.lubui.com:8443/static/icons/favicon-192x192.png";
                  url = "https://hass.lubui.com:8443";
                }
                {
                  title = "Music Assistant";
                  description = "音乐串流助手";
                  icon = "https://mass.lubui.com:8443/favicon.ico";
                  url = "https://mass.lubui.com:8443";
                }
                {
                  title = "Snapcast";
                  description = "音频多端同步";
                  icon = "https://snap.lubui.com:8443/logo.svg";
                  url = "https://snap.lubui.com:8443";
                }
                {
                  title = "ESPHome";
                  description = "ESP 固件编译";
                  icon = "https://esphome.io/favicon-512x512.png";
                  url = "https://esphome.lubui.com:8443";
                }
                {
                  title = "WLED";
                  description = "智能 LED 灯效";
                  icon = "https://kno.wled.ge/assets/images/ui/akemi/001_cheerful.png";
                  url = "https://wled.lubui.com:8443";
                }
                {
                  title = "Radicale";
                  description = "任务、日历与联系人";
                  icon = "https://caldav.lubui.com:8443/.web/css/logo.svg";
                  url = "https://caldav.lubui.com:8443";
                }
                {
                  title = "Umami";
                  description = "网站流量与行为分析";
                  icon = "https://umami.lubui.com:8443/apple-touch-icon.png";
                  url = "https://umami.lubui.com:8443";
                }
                {
                  title = "n8n";
                  description = "工作流自动化";
                  icon = "https://n8n.lubui.com:8443/favicon.ico";
                  url = "https://n8n.lubui.com:8443";
                }
                {
                  title = "PairDrop";
                  description = "局域网文件传输";
                  icon = "https://pairdrop.lubui.com:8443/images/apple-touch-icon.png";
                  url = "https://pairdrop.lubui.com:8443";
                }
              ];
              name = "Home Services";
            }
          ];
        };
      };

      services.nginx.virtualHosts."home.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          root = config.services.dashy.finalDrv;
          tryFiles = "$uri $uri/ /index.html";
        };
      };
    };
}
