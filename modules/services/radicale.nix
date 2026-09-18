{
  flake.nixosModules.radicale =
    { config, pkgs, ... }:
    {
      clan.core.vars.generators.radicale_basic_auth = {
        prompts.username.description = "Username for radicale";
        prompts.password.description = "Password for radicale";
        files.htpasswd.owner = "radicale";
        runtimeInputs = with pkgs; [ apacheHttpd ];
        script = ''
          htpasswd -n -B -b "$(cat $prompts/username)" "$(cat $prompts/password)" > $out/htpasswd
        '';
      };

      services.radicale = {
        enable = true;
        settings = {
          # server = {
          #   hosts = [
          #     "0.0.0.0:5232"
          #     "[::]:5232"
          #   ];
          # };
          auth = {
            type = "htpasswd";
            htpasswd_filename = config.clan.core.vars.generators.radicale_basic_auth.files.htpasswd.path;
            htpasswd_encryption = "autodetect";
          };
          storage = {
            filesystem_folder = "/var/lib/radicale/collections";
          };
        };
      };

      services.nginx.virtualHosts."caldav.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:5232";
          proxyWebsockets = true;
        };
      };
    };
}
