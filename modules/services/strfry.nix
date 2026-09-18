{
  flake.nixosModules.strfry =
    {
      pkgs,
      ...
    }:
    let
      domain = "nostr.lubui.com";
      port = 3113;
    in
    {
      environment.etc."strfry.conf".text = ''
        db = "/var/lib/strfry/"

        relay {
          bind = "127.0.0.1"
          port = ${toString port}

          info {
            name = "Nostr Relay on ${domain}"
            description = "A general-purpose Nostr relay"
            contact = ""
          }

          nofiles = 0
          maxWebsocketPayloadSize = 131072
          autoPingSeconds = 55
          enableTCPKeepalive = false

          writePolicy {
            plugin = ""
          }

          logging {
            # The default (invalidEvents = true) logs every rejected event,
            # which on a public relay means ~95k "ephemeral event expired"
            # lines per 10 minutes from clients replaying stale kind-2xxxx
            # events. journald rate-limits on top. Nothing actionable.
            invalidEvents = false
          }
        }
      '';

      systemd.services.strfry = {
        description = "strfry Nostr relay";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.strfry}/bin/strfry --config=/etc/strfry.conf relay";
          Restart = "on-failure";
          RestartSec = 5;

          DynamicUser = true;
          StateDirectory = "strfry";

          # WebSocket connections are long-lived; each client holds an fd.
          # strfry.conf sets nofiles=0 so it inherits this limit instead
          # of trying to raise it itself (which DynamicUser can't do).
          LimitNOFILE = 65536;

          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          ReadWritePaths = [ "/var/lib/strfry" ];
        };
      };

      services.nginx.virtualHosts.${domain} = {
        forceSSL = true;
        useACMEHost = "lubui.com";
        locations."/".extraConfig = ''
          proxy_pass http://127.0.0.1:${toString port};
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;

          # Nostr clients hold WebSocket connections open indefinitely.
          # nginx defaults to 60s read/send timeout which would drop any
          # connection that goes quiet between strfry's 55s pings.
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    };
}
