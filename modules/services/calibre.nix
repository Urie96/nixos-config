{
  flake.nixosModules.calibre =
    {
      config,
      pkgs,
      self',
      ...
    }:
    let
      packages = self'.packages;
    in
    {
      services.calibre-web = {
        enable = true;
        # package = packages.old-pkgs.calibre-web;
        options = {
          enableBookUploading = true;
        };
      };

      services.nginx.virtualHosts."calibre.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://[::1]:${toString config.services.calibre-web.listen.port}";
          proxyWebsockets = true;
        };
      };
    };
}
