{
  flake.nixosModules.ownfoil =
    {
      inputs',
      lib,
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;

      # run.py 里把端口写死成 0.0.0.0:8465（HTTP 和 LAN discovery 共用这个端口），
      # 改不了，所以这里只是把同一个数字写一遍给 nginx / firewall 用。
      port = 8465;

      stateDir = "/var/lib/ownfoil";

      # 库目录：ownfoil 自己不会写这里（默认只读就能浏览/下载），但 organizer、
      # 压缩、去重这些管理功能需要写权限。要启用它们还得让 ownfoil 用户能写：
      #   sudo chown -R ownfoil:ownfoil /mnt/hdd/switch_games
      libraryDir = "/mnt/hdd/switch_games";
    in
    {
      users.groups.ownfoil = { };
      users.users.ownfoil = {
        description = "Ownfoil Nintendo Switch library manager";
        isSystemUser = true;
        group = "ownfoil";
      };

      systemd.services.ownfoil = {
        description = "Ownfoil Nintendo Switch library manager";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        # /mnt/hdd 是 nofail 挂的，没插盘时这里只是一个 Wants，不会把服务卡住。
        unitConfig.RequiresMountsFor = [ libraryDir ];

        environment = {
          # ownfoil 默认把 config/ 和 data/ 放在包自己（只读的 store）里，
          # 必须显式指走。settings.yaml、keys.txt、secret_key、ownfoil.db 在 config，
          # titledb 缓存和封面图在 data。
          OWNFOIL_CONFIG_DIR = "${stateDir}/config";
          OWNFOIL_DATA_DIR = "${stateDir}/data";
          # gunicorn 26 的 control socket 落在 $XDG_RUNTIME_DIR/gunicorn.ctl，
          # 没有这个变量它会退到 $HOME/.gunicorn（HOME 在 systemd 下不可写）。
          XDG_RUNTIME_DIR = "/run/ownfoil";
          HOME = stateDir;
        };

        serviceConfig = {
          Type = "simple";
          User = "ownfoil";
          Group = "ownfoil";
          Restart = "on-failure";
          RestartSec = "3s";
          # ownfoil-server 是 nur-packages 里 wrap 出来的入口（gunicorn + 任务
          # worker pool），不是上游的 `ownfoil <base_dir>`。
          ExecStart = lib.getExe nur.ownfoil;
          StateDirectory = [
            "ownfoil/config"
            "ownfoil/data"
          ];
          RuntimeDirectory = "ownfoil";
          WorkingDirectory = stateDir;

          # Hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          ReadWritePaths = [ "-${libraryDir}" ];
        };
      };

      # 局域网内 Switch 直连 http://<ip>:8465；域名这条走 nginx 只是为了
      # 外网/带证书的场景。realtime 页面（任务进度、日志流）走 websocket。
      services.nginx.virtualHosts."ownfoil.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
          # 大 NSP/XCI 的下载是流式的，默认 60s 的读超时会误伤慢速客户端。
          extraConfig = ''
            proxy_read_timeout 1h;
            proxy_send_timeout 1h;
          '';
        };
      };
    };
}
