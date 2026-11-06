{
  flake.nixosModules.uptime-kuma =
    { config, ... }:
    {
      services.uptime-kuma.enable = true;

      services.nginx.virtualHosts."uptime.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.uptime-kuma.settings.PORT}";
          proxyWebsockets = true;
        };
      };
    };
}
