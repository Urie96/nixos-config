{
  flake.nixosModules.freshrss =
    { config, pkgs, ... }:
    {
      clan.core.vars.generators.freshrss = {
        prompts.password.persist = true;
        files.password.owner = config.services.freshrss.user;
      };

      services.freshrss = {
        enable = true;
        language = "zh-cn";
        defaultUser = "urie";
        baseUrl = "https://rss.lubui.com:8443";
        virtualHost = "rss.lubui.com";
        passwordFile = config.clan.core.vars.generators.freshrss.files.password.path;
        extensions = with pkgs.freshrss-extensions; [ youtube ];
      };

      services.nginx.virtualHosts."rss.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";
      };

    };
}
