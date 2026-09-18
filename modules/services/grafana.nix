{
  flake.nixosModules.grafana =
    { config, pkgs, ... }:
    let
      inherit (config.services) prometheus;
    in
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
              name = "Prometheus";
              type = "prometheus";
              url = "http://${prometheus.listenAddress}:${toString prometheus.port}";
            }
          ];
          # dashboards.settings.providers = [
          #
          # ];
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
