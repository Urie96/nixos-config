{
  flake.nixosModules.interval-web =
    { pkgs, ... }:
    let
      html = pkgs.fetchurl {
        url = "https://gist.github.com/Urie96/0f88a7c4ecc09431f1b2a39962074717/raw/943d8f375b85a45aa5ba7b17c7fca3fcdd42fd8a/interval.html";
        hash = "sha256-hsLnecEv11dcnNmJngfDSOqpo6At4q3Xzu1HpcjGU54=";
      };

      root = pkgs.runCommand "interval-web-root" { } ''
        mkdir -p $out
        ln -s ${html} $out/index.html
      '';

    in
    {
      services.nginx.virtualHosts."interval.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          root = "${root}";
          tryFiles = "$uri $uri/ /index.html";
        };
      };
    };
}
