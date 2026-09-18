{
  flake.nixosModules.vaultwarden =
    { config, ... }:
    {
      clan.core.vars.generators.vaultwarden = {
        prompts.admin_token.description = "Admin token for vaultwarden";
        files.env = { };
        script = ''
          echo "ADMIN_TOKEN=$(cat $prompts/admin_token)" >> $out/env
        '';
      };

      services.vaultwarden = {
        enable = true;
        environmentFile = config.clan.core.vars.generators.vaultwarden.files.env.path;
        config = {
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = 8222;
          DOMAIN = "https://pw.lubui.com:8443";
          SIGNUPS_ALLOWED = false;
          ENABLE_WEBSOCKET = true;
        };
      };

      services.nginx.virtualHosts."pw.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
          proxyWebsockets = true;
        };
      };
    };
}
