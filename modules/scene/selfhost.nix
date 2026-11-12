{ self, ... }: {
  flake.nixosModules.selfhost = {
    imports = with self.nixosModules; [
      llama
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
      monitoring
      immich
      paperless
      paperless-gpt
      jellyfin-server
      love-yue
      interval-web
      webdav
      harmonia
      cache-push
      apprise-server
      # llm-api-proxy
      postgresql
      lldap
      authelia
      audiobookshelf
      searx
      calibre
      kosync
      ownfoil
      xiaozhi-server-rs
      # pi-server
    ];
  };
}
