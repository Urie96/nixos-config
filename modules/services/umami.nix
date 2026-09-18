{
  flake.nixosModules.umami =
    {
      config,
      pkgs,
      ...
    }:
    {
      clan.core.vars.generators.umami = {
        files.app_secret = { };
        runtimeInputs = with pkgs; [ openssl ];
        script = ''
          openssl rand -hex 32 >$out/app_secret
        '';
      };

      services.umami = {
        enable = true;
        settings = {
          PORT = 3107;
          APP_SECRET_FILE = config.clan.core.vars.generators.umami.files.app_secret.path;
        };
      };

      services.nginx.virtualHosts."umami.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.umami.settings.PORT}";
          proxyWebsockets = true;
          recommendedProxySettings = false; # X-Forwarded-Host需要传端口
          extraConfig = ''
            proxy_set_header        X-Real-IP $remote_addr;
            proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header        X-Forwarded-Proto $scheme;
            proxy_set_header        X-Forwarded-Host $host:$server_port;
            proxy_set_header        X-Forwarded-Server $host;
          '';
        };
      };
    };
}
