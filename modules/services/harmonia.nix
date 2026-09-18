{
  flake.nixosModules.harmonia =
    { config, pkgs, ... }:
    {
      clan.core.vars.generators.harmonia = {
        files."harmonia.secret" = { };
        files."harmonia.pub".secret = false;
        runtimeInputs = with pkgs; [ nix ];
        script = ''
          nix-store --generate-binary-cache-key cache.lubui.com-2 $out/harmonia.secret $out/harmonia.pub
        '';
      };

      services.harmonia.cache = {
        enable = true;
        signKeyPaths = [ config.clan.core.vars.generators.harmonia.files."harmonia.secret".path ];
        settings = {
          priority = 30;
        };
      };

      services.nginx.virtualHosts."cache.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:5000";
          proxyWebsockets = true;
        };
      };
    };
}
