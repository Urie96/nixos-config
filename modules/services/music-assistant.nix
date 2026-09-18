{
  flake.nixosModules.music-assistant =
    { pkgs, ... }:
    {
      systemd.services.music-assistant.path = [ pkgs.snapcast ];
      services.music-assistant = {
        enable = true;
        # list of (one of "airplay", "apple_music", "audible", "audiobookshelf", "bluesound", "builtin", "builtin_player", "chromecast", "deezer", "dlna", "fanarttv", "filesystem_local", "filesystem_smb", "fully_kiosk", "gpodder", "hass", "hass_players", "ibroadcast", "itunes_podcasts", "jellyfin", "lastfm_scrobble", "listenbrainz_scrobble", "musicbrainz", "opensubsonic", "player_group", "plex", "podcastfeed", "qobuz", "radiobrowser", "siriusxm", "snapcast", "sonos", "sonos_s1", "soundcloud", "spotify", "spotify_connect", "squeezelite", "template_player_provider", "test", "theaudiodb", "tidal", "tunein", "ytmusic")
        providers = [
          "opensubsonic"
          "snapcast"
          "sendspin"
          "audiobookshelf"
          "neteasecloudmusic"
          "fastmcp_server"
        ];
      };

      services.nginx.virtualHosts."mass.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:8095";
          proxyWebsockets = true;
        };
      };
    };
}
