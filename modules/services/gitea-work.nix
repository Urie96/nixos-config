{ self, ... }:
{
  flake.sysModules.gitea-work = { config, pkgs, ... }: {
    imports = with self.sysModules; [
      gitea
    ];

    services.gitea = {
      enable = true;
      settings = {
        log.LEVEL = "Error";
        service.DISABLE_REGISTRATION = false;
        server = {
          ROOT_URL = "http://10.37.107.28:3000/";
          HTTP_PORT = 3000;
          HTTP_ADDR = "0.0.0.0";
          DISABLE_ROUTER_LOG = true;
          DISABLE_SSH = true;
          PUBLIC_URL_DETECTION = "never";
        };
      };
    };
  };
}
