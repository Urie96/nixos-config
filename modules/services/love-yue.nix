{
  flake.nixosModules.love-yue =
    { inputs', ... }:
    let
      nur = inputs'.nur-packages.packages;
    in
    {
      services.nginx.virtualHosts."huyue-src.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          root = "${nur.love-yue}/share/public";
          tryFiles = "$uri $uri/ /index.html";
        };
      };
    };
}
