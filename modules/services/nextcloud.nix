{
  flake.nixosModules.nextcloud =
    { config, pkgs, ... }:
    {
      clan.core.vars.generators.nextcloud = {
        prompts.password.persist = true;
        files.password = { };
      };

      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud33;
        hostName = "cloud.lubui.com";
        https = true;
        # appstoreEnable = false;
        config = {
          dbtype = "pgsql";
          dbname = "nextcloud";
          dbuser = "nextcloud";
          dbhost = "/run/postgresql";
          adminuser = "urie";
          adminpassFile = config.clan.core.vars.generators.nextcloud.files.password.path;
        };
        settings.default_phone_region = "CN";
        settings.dbtableprefix = "oc_";
      };

      services.postgresql = {
        enable = true;
        ensureDatabases = [ "nextcloud" ];
        ensureUsers = [
          {
            name = "nextcloud";
            ensureDBOwnership = true;
          }
        ];
      };

      services.nginx.virtualHosts."cloud.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";
      };
    };
}
