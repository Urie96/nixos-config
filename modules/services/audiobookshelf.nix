{
  flake.nixosModules.audiobookshelf =
    { config, ... }:
    {
      services.audiobookshelf = {
        enable = true;
        port = 3111;
      };

      services.nginx.virtualHosts."audiobook.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.audiobookshelf.port}";
          proxyWebsockets = true;
        };
      };
    };
}
