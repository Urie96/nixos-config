{
  flake.nixosModules.memos = {
    services.memos.enable = true;

    services.nginx.virtualHosts."memos.lubui.com" = {
      addSSL = true;
      useACMEHost = "lubui.com";

      locations."/" = {
        proxyPass = "http://127.0.0.1:5230";
        proxyWebsockets = true;
      };
    };
  };
}
