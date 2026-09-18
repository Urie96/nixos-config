{
  flake.nixosModules.openlist =
    {
      lib,
      utils,
      pkgs,
      ...
    }:
    let
      settings = {
        site_url = "https://openlist.lubui.com:8443"; # web端预览本地文件时需要
        database.table_prefix = "x_"; # keep same as docker default
        scheme = {
          address = "127.0.0.1";
          unix_file = "/run/openlist/openlist.sock";
          unix_file_perm = "666";
        };
      };

      stateDir = "/var/lib/openlist";
    in
    {
      users.users.openlist = {
        description = "OpenList user";
        isSystemUser = true;
        group = "openlist";
      };
      users.groups.openlist = { };

      systemd.services.openlist = {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        # If mutableConfig is true, overwrite the contents of cfg.settings to the existing configuration
        script = ''
          ${utils.genJqSecretsReplacementSnippet settings "/run/openlist/new"}

          [ -e "${stateDir}/config.json" ] && cp "${stateDir}/config.json" /run/openlist/old
          ${lib.getExe pkgs.jq} -s '.[0] * .[1]' /run/openlist/old /run/openlist/new > /run/openlist/result
          mv /run/openlist/result /run/openlist/new
          rm -f /run/openlist/old
          mv /run/openlist/new "${stateDir}/config.json"
          ${pkgs.openlist}/bin/OpenList server --data ${stateDir} --log-std
        '';
        serviceConfig = {
          Type = "simple";
          User = "openlist";
          Group = "openlist";
          Restart = "on-failure";
          RestartSec = "3s";
          StateDirectory = "openlist";
          RuntimeDirectory = "openlist";
          WorkingDirectory = stateDir;
          # Hardening
          PrivateTmp = true;
          PrivateUsers = true;
          NoNewPrivileges = true;
          RestrictSUIDSGID = true;
          RemoveIPC = true;
          PrivateDevices = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectHostname = true;
          ProtectProc = "invisible";
          MemoryDenyWriteExecute = true;
          UMask = "0077";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
        };
      };

      services.nginx.virtualHosts."openlist.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://unix:${settings.scheme.unix_file}:/";
          proxyWebsockets = true;
          recommendedProxySettings = false; # host需要传端口
          extraConfig = ''
            proxy_set_header        Host $host:$server_port;
            proxy_set_header        X-Real-IP $remote_addr;
            proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header        X-Forwarded-Proto $scheme;
            proxy_set_header        X-Forwarded-Host $host;
            proxy_set_header        X-Forwarded-Server $host;
          '';
        };
      };
    };
}
