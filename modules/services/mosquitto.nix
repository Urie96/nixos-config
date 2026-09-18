{
  flake.nixosModules.mosquitto =
    { config, ... }:
    {
      clan.core.vars.generators.mosquitto = {
        prompts.password.persist = true;
        files.password.owner = "mosquitto";
      };

      services.mosquitto = {
        enable = true;
        listeners = [
          {
            address = "192.168.2.1";
            acl = [ "pattern readwrite #" ];
            omitPasswordAuth = true;
            settings.allow_anonymous = true;
          }
          {
            address = "127.0.0.1";
            acl = [ "pattern readwrite #" ];
            omitPasswordAuth = true;
            settings.allow_anonymous = true;
          }
          {
            address = "192.168.1.7";
            port = 1883;
            acl = [ "pattern readwrite #" ];
            users.iot = {
              passwordFile = config.clan.core.vars.generators.mosquitto.files.password.path;
            };
          }
        ];
      };
    };
}
