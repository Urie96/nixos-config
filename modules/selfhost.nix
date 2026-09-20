{ self, ... }: {
  flake.nixosModules.selfhost = {
    imports = with self.nixosModules; [
      avahi
      kea
      umami
      nginx
      dashy
      music-assistant
      home-assistant
      freshrss
      btrbk
      navidrome
      gitea
      podman
      openlist
      samba
      acme
      radicale
      mosquitto
      stash
      snapserver
      netease-cloud-music-api
      apple-music-api
      esphome
      translate-server
      ddns-go
      vaultwarden
      rsshub
      memos
      ntfy
      pairdrop
      uptime-kuma
      immich
      jellyfin-server
      love-yue
      interval-web
      sso
      webdav
      harmonia
      apprise-server
      # llm-api-proxy
      postgresql
      authelia
      audiobookshelf
      searx
      calibre
      kosync
      xiaozhi-server-rs
      # pi-server
    ];
  };
}
