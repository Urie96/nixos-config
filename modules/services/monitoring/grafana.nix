{
  flake.nixosModules.grafana =
    { config, pkgs, ... }:
    {
      clan.core.vars.generators.grafana = {
        files.security_key.owner = "grafana";
        runtimeInputs = with pkgs; [ openssl ];
        script = ''
          openssl rand -hex 32 >$out/security_key
        '';
      };

      services.grafana = {
        enable = true;
        settings = {
          server = {
            protocol = "socket";
            socket_mode = "0666";
            enforce_domain = true;
            enable_gzip = true;
            domain = "grafana.lubui.com";
            # 走 unix socket 时 grafana 不知道外部协议/端口
            root_url = "https://grafana.lubui.com:8443";
          };
          users = {
            default_language = "zh-Hans";
            # 通过 auth.proxy 自动建出来的账号直接给 Admin（就一个用户）。
            auto_assign_org_role = "Admin";
            allow_sign_up = false;
            viewers_can_edit = false;
          };
          security.secret_key = "$__file{${config.clan.core.vars.generators.grafana.files.security_key.path}}";

          # 免登录走 nginx 的 forward-auth：authelia 认过之后把 uid 放进
          # Remote-User 头，grafana 直接信任它并自动建号。
          #
          # 注意这里**故意不关** auth.basic 和登录表单：
          #   - 头只在经过 nginx 的路径上存在，直接访问 unix socket
          #     （socket_mode = 0666，本机任何用户都能连）时头是空的，会退回
          #     自带登录框 —— 这是 authelia 挂掉时唯一的救急入口。
          #   - basic auth 也保住了给脚本/CLI 用的 API 访问。
          # 想彻底关掉登录框就把 auth.disable_login_form 打开，但那样忘掉
          # admin 密码就只能 ssh 进去 `grafana cli admin reset-password` 了。
          "auth.proxy" = {
            enabled = true;
            header_name = "Remote-User";
            header_property = "username";
            auto_sign_up = true;
            headers = "Email:Remote-Email Name:Remote-Name";
            # 单位是分钟（不是秒）：本地缓存多久重新从 header 同步一次。
            # 改 lldap 里的邮箱/昵称后最多等这么久才生效，0 = 每次请求都同步。
            sync_ttl = 15;
          };
          # 在 grafana 里点退出 -> 顺手把 authelia 的 session 也退掉，
          auth.signout_redirect_url = config.my.authelia.url + "/logout";

          # Prevents Grafana from phoning home
          #analytics.reporting_enabled = false;
        };
        provision = {
          enable = true;
          datasources.settings.datasources = [
            {
              # 数据源是 VictoriaMetrics 的 Prometheus 兼容 API，
              # 不是 Prometheus server（services.prometheus.enable = false）
              name = "VictoriaMetrics";
              uid = "victoriametrics";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:8428";
              isDefault = true;
            }
          ];
          dashboards.settings.providers = [
            {
              name = "monitoring";
              type = "file";
              disableDeletion = false;
              updateIntervalSeconds = 60;
              options.path = "${./grafana-dashboards}";
            }
          ];
        };
      };

      services.nginx.virtualHosts."grafana.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        extraConfig = config.my.authelia.nginxSsoConfig;

        locations = {
          "/authelia" = {
            extraConfig = config.my.authelia.nginxVerifyLocation;
          };
          "/" = {
            proxyPass = "http://unix:${config.services.grafana.settings.server.socket}:/";
            proxyWebsockets = true;
            extraConfig = config.my.authelia.nginxSsoUserHeaders;
          };
        };
      };
    };
}
