{
  flake.nixosModules.snapserver =
    { ... }:
    {
      services.snapserver = {
        enable = true;
        settings = {
          tcp.enabled = true;
          http.enabled = true;
          stream.source = "";
        };
      };

      # TODO: sso protect
      services.nginx.virtualHosts."snap.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:1780";
          proxyWebsockets = true;
        };
      };
    };
}
