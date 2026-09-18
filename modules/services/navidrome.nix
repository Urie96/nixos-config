{
  flake.nixosModules.navidrome = {
    services.navidrome = {
      enable = true;
      settings = {
        MusicFolder = "/var/lib/navidrome/music";
        Address = "unix:/run/navidrome/navidrome.sock";
        UnixSocketPerm = "666";
        SessionTimeout = "240h";
        DefaultLanguage = "zh-Hans";
        EnableSharing = true;
      };
    };

    services.nginx.virtualHosts."music.lubui.com" = {
      addSSL = true;
      useACMEHost = "lubui.com";

      locations."/" = {
        proxyPass = "http://unix:/run/navidrome/navidrome.sock:/";
        proxyWebsockets = true;
      };
    };
  };
}
