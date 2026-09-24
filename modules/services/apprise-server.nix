{
  flake.nixosModules.apprise-server =
    {
      pkgs,
      lib,
      inputs',
      ...
    }:
    let
      yamlFormat = pkgs.formats.yaml { };

      nur = inputs'.nur-packages.packages;
    in
    {
      systemd.services.apprise-server = {
        enable = true;
        description = "apprise-server Backend";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          LISTEN_PORT = "3102";
          LISTEN_HOST = "127.0.0.1";
          CONFIG_PATH = toString (
            yamlFormat.generate "apprise-config.yaml" {
              urls = [
                {
                  "tgram://6396149308:AAGa5Bd9KbQsp795ehO3o0VQ3VwdNEiwTlc/-1002435707809" = [ { tag = "me"; } ];
                  "ntfy://localhost:3112/cTpCazcWbXmkHLoG" = [ { tag = "me"; } ];
                }
              ];
            }
          );
        };
        serviceConfig = {
          Restart = "always";
          DynamicUser = true;
          ExecStart = lib.getExe nur.apprise-server;
        };
      };
    };
}
