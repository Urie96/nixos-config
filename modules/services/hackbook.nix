{
  flake.nixosModules.hackbook =
    {
      config,
      inputs',
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
    in
    {
      systemd.services.hackbook = {
        enable = true;
        description = "hackbook Backend";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          PORT = "3103";
          HOST = "127.0.0.1";
          STORAGE_PATH = "/var/lib/hackbook";
          DATABASE_URL = "/var/lib/hackbook/hackbook.db";
        };
        serviceConfig = {
          StateDirectory = "hackbook";
          Restart = "always";
          DynamicUser = true;
          ExecStart = "${nur.hackbook}/bin/hackbook-server";
        };
      };

      services.nginx.virtualHosts."book.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations = {
          "/api" = {
            priority = 10;
            proxyPass = "http://127.0.0.1:${toString config.systemd.services.hackbook.environment.PORT}";
            proxyWebsockets = true;
          };
          "/" = {
            priority = 20;
            root = "${nur.hackbook}/share/public";
            tryFiles = "$uri $uri/ /index.html";
          };
          "/images" = {
            priority = 5;
            root = "/var/lib/nginx/static/hackbook";
          };
        };
      };
    };
}
