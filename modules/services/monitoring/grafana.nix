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

            # Alternatively, if you want to server Grafana from a subpath:
            # domain = "your.domain";
            # root_url = "https://your.domain/grafana/";
            # serve_from_sub_path = true;
          };
          users = {
            default_language = "zh-Hans";
          };
          security.secret_key = "$__file{${config.clan.core.vars.generators.grafana.files.security_key.path}}";

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
              options.path = "${./monitoring/grafana-dashboards}";
            }
          ];
        };
      };

      services.nginx.virtualHosts."grafana.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://unix:${config.services.grafana.settings.server.socket}:/";
          proxyWebsockets = true;
        };
      };
    };
}
