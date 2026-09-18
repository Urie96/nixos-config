{
  flake.nixosModules.pairdrop =
    { config, ... }:
    {
      services.pairdrop = {
        enable = true;
        environment.WS_FALLBACK = "true";
      };

      services.nginx.virtualHosts."pairdrop.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.pairdrop.port}";
          proxyWebsockets = true;
        };
      };
    };
}
