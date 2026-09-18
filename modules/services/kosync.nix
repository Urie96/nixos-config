{
  flake.nixosModules.kosync =
    {
      pkgs,
      inputs',
      lib,
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
      port = 3114;
    in
    {
      systemd.services.kosync = {
        enable = true;
        description = "KOReader sync server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          KOSYNC_ADDR = "127.0.0.1:${toString port}";
        };
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = "3s";
          DynamicUser = true;
          StateDirectory = "kosync";
          WorkingDirectory = "/var/lib/kosync";
          ExecStart = lib.getExe nur.kosync;
          # Hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          ReadWritePaths = [ "/var/lib/kosync" ];
        };
      };

      services.nginx.virtualHosts."kosync.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
        };
      };
    };
}
