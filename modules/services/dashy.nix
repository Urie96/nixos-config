{
  flake.nixosModules.dashy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
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

      # 本机服务的条目：只有这台机器上真的部署了这个服务才出现。关掉某个服务
      # 的 `enable` 之后，dashboard 上不会留下一条指向不存在服务的死链。
      ifEnabled = enable: entry: lib.optionals enable [ entry ];

      # 少数模块没有 `enable` 开关（被 import 就等于部署），就退一步看它声明的
      # systemd 服务 / podman 容器 / nginx vhost 在不在：模块没被 import 时为
      # false，效果和 enable 一样。
      #
      # 另有几个条目是不在本仓库托管的外部服务（gotify、aria2、WLED 等，跑在
      # 别的设备上），nix 无从判断，条目恒定存在。
      always = entry: [ entry ];
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
            theme = "catppuccin";
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
              items = lib.flatten [
                # —— 媒体 ——
                (ifEnabled config.services.immich.enable {
                  description = "照片管理";
                  icon = "https://immich.lubui.com:8443/apple-icon-180.png";
                  title = "Immich";
                  url = "https://immich.lubui.com:8443";
                })
                (ifEnabled config.services.jellyfin.enable {
                  title = "Jellyfin";
                  description = "媒体服务器";
                  # jellyfin 的 web 图标是带 hash 的文件名（/web/touchicon.<hash>.png），
                  # 每次升级都会变，只能用 CDN 上的固定图标。
                  icon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/jellyfin.png";
                  url = "https://jellyfin.lubui.com:8443";
                })
                (ifEnabled config.services.navidrome.enable {
                  description = "音乐服务";
                  icon = "https://music.lubui.com:8443/app/android-chrome-192x192.png";
                  title = "Navidrome";
                  url = "https://music.lubui.com:8443";
                })
                (ifEnabled config.services.music-assistant.enable {
                  title = "Music Assistant";
                  description = "音乐串流助手";
                  icon = "https://mass.lubui.com:8443/favicon.ico";
                  url = "https://mass.lubui.com:8443";
                })
                (ifEnabled config.services.snapserver.enable {
                  title = "Snapcast";
                  description = "音频多端同步";
                  icon = "https://snap.lubui.com:8443/logo.svg";
                  url = "https://snap.lubui.com:8443";
                })
                (ifEnabled config.services.audiobookshelf.enable {
                  title = "Audiobookshelf";
                  description = "有声书与播客";
                  icon = "https://audiobook.lubui.com:8443/favicon.ico";
                  url = "https://audiobook.lubui.com:8443";
                })
                (ifEnabled config.services.calibre-web.enable {
                  title = "Calibre-Web";
                  description = "电子书库";
                  icon = "https://calibre.lubui.com:8443/static/favicon.ico";
                  url = "https://calibre.lubui.com:8443";
                })
                (ifEnabled (config.systemd.services ? ownfoil) {
                  title = "Ownfoil";
                  description = "Switch 游戏库与商店";
                  icon = "https://ownfoil.lubui.com:8443/static/logo/logo-256.png";
                  url = "https://ownfoil.lubui.com:8443";
                })
                (ifEnabled (config.systemd.services ? openlist) {
                  description = "多网盘挂载文件列表";
                  icon = "https://doc.oplist.org/favicon.svg";
                  title = "OpenList";
                  url = "https://openlist.lubui.com:8443";
                })

                # —— 阅读与笔记 ——
                (ifEnabled config.services.freshrss.enable {
                  description = "信息流聚合";
                  icon = "https://rss.lubui.com:8443/themes/icons/favicon-256.png";
                  title = "FreshRSS";
                  url = "https://rss.lubui.com:8443";
                })
                (ifEnabled config.services.memos.enable {
                  title = "Memos";
                  description = "碎片笔记";
                  icon = "https://memos.lubui.com:8443/logo.webp";
                  url = "https://memos.lubui.com:8443";
                })
                (ifEnabled config.services.paperless.enable {
                  title = "Paperless-ngx";
                  description = "文档扫描归档";
                  icon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/paperless-ngx.png";
                  url = "https://paperless.lubui.com:8443";
                })
                (ifEnabled config.services.paperless-gpt.enable {
                  title = "paperless-gpt";
                  description = "扫描件重新识别 / 元数据建议";
                  icon = "https://paperless-gpt.lubui.com:8443/favicon.ico";
                  url = "https://paperless-gpt.lubui.com:8443";
                })
                (always {
                  title = "Code Notes";
                  description = "我的笔记";
                  icon = "https://lubui.com/favicon.svg";
                  url = "https://lubui.com";
                })
                (ifEnabled (config.systemd.services ? hackbook) {
                  title = "HackBook";
                  description = "程序员专栏";
                  icon = "https://book.lubui.com:8443/favicon.svg";
                  url = "https://book.lubui.com:8443";
                })
                (ifEnabled (config.services.nginx.virtualHosts ? "huyue-src.lubui.com") {
                  title = "Love Yue";
                  description = "在一起纪念";
                  icon = "https://huyue-src.lubui.com:8443/favicon.svg";
                  url = "https://huyue-src.lubui.com:8443/";
                })
                (ifEnabled (config.services.nginx.virtualHosts ? "interval.lubui.com") {
                  title = "Interval";
                  description = "间隔计时器";
                  # 这个页面（gist 里的单文件）没有 favicon，借用 lucide 的图标
                  icon = "https://cdn.jsdelivr.net/npm/lucide-static/icons/timer.svg";
                  url = "https://interval.lubui.com:8443";
                })

                # —— 智能家居 ——
                (ifEnabled config.services.home-assistant.enable {
                  title = "Home Assistant";
                  description = "智能家居自动化平台";
                  icon = "https://hass.lubui.com:8443/static/icons/favicon-192x192.png";
                  url = "https://hass.lubui.com:8443";
                })
                (ifEnabled (config.virtualisation.oci-containers.containers ? esphome) {
                  title = "ESPHome";
                  description = "ESP 固件编译";
                  icon = "https://esphome.io/favicon-512x512.png";
                  url = "https://esphome.lubui.com:8443";
                })
                (always {
                  title = "WLED";
                  description = "智能 LED 灯效";
                  icon = "https://kno.wled.ge/assets/images/ui/akemi/001_cheerful.png";
                  url = "https://wled.lubui.com:8443";
                })

                # —— 开发与自动化 ——
                (ifEnabled config.services.gitea.enable {
                  title = "Gitea";
                  description = "自建 Git 服务";
                  icon = "https://git.lubui.com:8443/assets/img/logo.svg";
                  url = "https://git.lubui.com:8443";
                })
                (ifEnabled config.services.n8n.enable {
                  title = "n8n";
                  description = "工作流自动化";
                  icon = "https://n8n.lubui.com:8443/favicon.ico";
                  url = "https://n8n.lubui.com:8443";
                })
                (ifEnabled config.services.umami.enable {
                  title = "Umami";
                  description = "网站流量与行为分析";
                  icon = "https://umami.lubui.com:8443/apple-touch-icon.png";
                  url = "https://umami.lubui.com:8443";
                })
                (ifEnabled config.services.searx.enable {
                  title = "SearXNG";
                  description = "元搜索引擎";
                  icon = "https://search.lubui.com:8443/static/themes/simple/img/favicon.png";
                  url = "https://search.lubui.com:8443";
                })

                # —— 网络与代理 ——
                (ifEnabled config.services.sing-box.enable {
                  title = "SingBox";
                  description = "网络代理";
                  icon = "https://sing-box.sagernet.org/assets/icon.svg";
                  url = "https://singbox.lubui.com:8443/redirect";
                })
                (ifEnabled config.services.pairdrop.enable {
                  title = "PairDrop";
                  description = "局域网文件传输";
                  icon = "https://pairdrop.lubui.com:8443/images/apple-touch-icon.png";
                  url = "https://pairdrop.lubui.com:8443";
                })

                # —— 账号与监控 ——
                (ifEnabled config.services.vaultwarden.enable {
                  description = "密码管理";
                  icon = "https://pw.lubui.com:8443/images/safari-pinned-tab.svg";
                  title = "Vaultwarden";
                  url = "https://pw.lubui.com:8443";
                })
                (ifEnabled config.services.radicale.enable {
                  title = "Radicale";
                  description = "任务、日历与联系人";
                  icon = "https://caldav.lubui.com:8443/.web/css/logo.svg";
                  url = "https://caldav.lubui.com:8443";
                })
                (ifEnabled config.services.ntfy-sh.enable {
                  title = "ntfy";
                  description = "手机与浏览器推送";
                  icon = "https://ntfy.lubui.com:8443/static/images/favicon.ico";
                  url = "https://ntfy.lubui.com:8443";
                })
                (ifEnabled config.services.uptime-kuma.enable {
                  description = "服务可用性监控";
                  icon = "https://uptime.lubui.com:8443/icon.svg";
                  title = "Uptime Kuma";
                  url = "https://uptime.lubui.com:8443";
                })
                (ifEnabled config.services.grafana.enable {
                  title = "Grafana";
                  description = "指标监控面板";
                  # 站点在 authelia 后面，未登录时 favicon 会被重定向走
                  icon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/grafana.png";
                  url = "https://grafana.lubui.com:8443";
                })
                (ifEnabled config.services.lldap.enable {
                  title = "LLDAP";
                  description = "统一账号目录";
                  icon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/lldap.png";
                  url = "https://lldap.lubui.com:8443";
                })
                (ifEnabled config.services.authelia.instances.main.enable {
                  title = "Authelia";
                  description = "单点登录门户";
                  icon = "https://auth.lubui.com:8443/favicon.ico";
                  url = "https://auth.lubui.com:8443";
                })
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
