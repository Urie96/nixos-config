{
  flake.nixosModules.gitea =
    { config, ... }:
    {
      services.gitea = {
        enable = true;
        settings.log.LEVEL = "Error";
        settings.service.DISABLE_REGISTRATION = true;
        # settings.metrics.ENABLED = true;
        settings.server = {
          DISABLE_ROUTER_LOG = true;
          ROOT_URL = "https://git.lubui.com:8443";
          DOMAIN = "lubui.com";
          PROTOCOL = "http+unix";
          DISABLE_SSH = true;
        };
        settings.security = {
          # DISABLE_GIT_HOOKS = false;
        };
      };

      services.nginx.virtualHosts."git.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";
        locations."/".proxyPass = "http://unix:${config.services.gitea.settings.server.HTTP_ADDR}:/";
      };
    };
}
