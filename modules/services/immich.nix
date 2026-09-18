{
  flake.nixosModules.immich =
    { config, ... }:
    {
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        machine-learning.environment.HF_ENDPOINT = "https://hf-mirror.com";
      };

      services.nginx.virtualHosts."immich.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.immich.port}";
          proxyWebsockets = true;
        };
      };
    };
}
