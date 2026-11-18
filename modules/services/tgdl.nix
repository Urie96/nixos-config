{
  flake.nixosModules.tgdl =
    {
      config,
      inputs',
      lib,
      pkgs,
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;

      user = "tgdl";
      stateDir = "/var/lib/tgdl";

      # 下载目录和状态分开：session.json / state.db 留在 /var/lib/tgdl（@varlib
      # 会被 btrbk 备份，小文件留着无妨）；下载的视频放外挂机械盘（subvol @data，
      # 不进任何快照），别把 @varlib 的快照/备份撑爆。
      downloadDir = "/mnt/hdd/downloads/tgdl";

      # 配置里不再放任何凭据：api_id / api_hash 走 systemd 的 EnvironmentFile
      # （TGDL_API_ID / TGDL_API_HASH，见 modules/services/tgdl.nix 里的 vars
      # generator），手机号和两步验证密码只由 `tgdl-login` 交互式询问。
      settings = {
        session_file = "${stateDir}/session.json";
        state_file = "${stateDir}/state.db";
        download_dir = downloadDir;

        poll_interval = "1h";
        threads = 4;
        retries = 5;
        log_level = "info";
        redownload_missing_files = false;
        backfill = false;

        filters = {
          max_file_size = 0;
          min_duration = 0;
          max_duration = 0;
        };

        # 数字 id 依赖 state.db 里缓存的 access_hash（从原 Python 版迁移过来的）。
        # 重建 state.db 后要改成 "@用户名" 跑一次才能重新解析。
        channels = [
          {
            channel = "-1003331047977";
            dir = "资源下载器";
            backfill = true;
          }
        ];
      };

      configFile = (pkgs.formats.yaml { }).generate "tgdl-config.yaml" settings;

      # 只有 root 能读的 EnvironmentFile（clan vars 生成，owner=root mode=0400）。
      envFile = config.clan.core.vars.generators.tgdl.files.env.path;
    in
    {
      # 用静态系统用户而不是 DynamicUser：登录必须在服务之外交互式跑一次，
      # 而且 session.json / state.db / 下载的文件要一直留在 /var/lib/tgdl 里。
      users.groups.${user} = { };
      users.users.${user} = {
        description = "tgdl Telegram channel video downloader";
        isSystemUser = true;
        group = user;
        home = stateDir;
      };

      clan.core.vars.generators.tgdl = {
        # 只能人工填的值，来自 https://my.telegram.org → API development tools。
        prompts.api_id = {
          description = "Telegram api_id (my.telegram.org → API development tools)";
          persist = true;
        };
        prompts.api_hash = {
          description = "Telegram api_hash";
          type = "hidden";
          persist = true;
        };

        # prompt 带 persist 时 clan 会把值原样落到 $out/<name>，要为它们声明文件
        # 才会被存进 vars store；deploy = false 表示只当本生成器的输入，不落到机器上。
        files.api_id.deploy = false;
        files.api_hash.deploy = false;

        # 只有 root 能读的 EnvironmentFile，systemd 在降权之前读它。
        files.env = {
          owner = "root";
          group = "root";
          mode = "0400";
          # 凭据换了就重启服务。
          restartUnits = [ "tgdl.service" ];
        };

        script = ''
          umask 0077
          {
            echo "TGDL_API_ID=$(cat $prompts/api_id)"
            echo "TGDL_API_HASH=$(cat $prompts/api_hash)"
          } > $out/env
        '';
      };

      systemd.services.tgdl = {
        description = "tgdl — Telegram channel video downloader";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          User = user;
          Group = user;
          ExecStart = "${lib.getExe nur.tgdl} -config ${configFile}";
          # tgdl 只从环境读 api_id / api_hash（clan vars 生成，root only）。
          # 还没 `clan vars generate` 时这里是 clan 的占位 "/no-such-path"，
          # unit 会直接起不来并报 Failed to load environment files。
          EnvironmentFile = envFile;

          # /var/lib/tgdl（session.json、state.db）由 systemd 建好并 chown 给 tgdl。
          # 下载目录在外挂盘上，StateDirectory 管不到，由下面的 tmpfiles 建、
          # ReadWritePaths 单独放行。
          StateDirectory = "tgdl";
          WorkingDirectory = stateDir;
          ReadWritePaths = [ downloadDir ];

          # session 还没登录时 tgdl 以 1 退出；RestartSec 别太短，免得刷日志。
          Restart = "on-failure";
          RestartSec = "30s";
          # SIGTERM 会让正在下的文件保留 .part，下次启动接着下。
          KillSignal = "SIGTERM";
          TimeoutStopSec = "60s";

          StandardOutput = "journal";
          StandardError = "journal";
          LogRateLimitIntervalSec = 0;

          # Hardening（和上游 tgdl.service 一致）
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          LockPersonality = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          SystemCallFilter = [ "@system-service" ];
          SystemCallErrorNumber = "EPERM";
        };

        # 下载目录在外挂盘上：ProtectSystem=strict 下要显式放行（见 ReadWritePaths），
        # 目录得先建好并 chown 给 tgdl（StateDirectory 只管 /var/lib/tgdl）。
        # /mnt/hdd 是 nofail 挂的，没插盘时这里只是一个空挂载点，靠下面的
        # RequiresMountsFor 让服务起不来，而不是把下载写进根分区。
        unitConfig.RequiresMountsFor = [ downloadDir ];
      };

      # 下载目录全局可读：jellyfin / samba / 主用户都要直接读下载的视频，
      # 不靠加组。tgdl 新建的子目录/文件走默认 umask 0022，也是 0755/0644。
      systemd.tmpfiles.rules = [
        "d ${downloadDir} 0755 ${user} ${user} - -"
      ];

      # 首次登录（要在 TTY 里收 Telegram 验证码），登录态写进
      # /var/lib/tgdl/session.json，之后服务才有权限跑。
      # EnvironmentFile 是 root only 的，所以这里用 systemd-run 起一个以 tgdl
      # 身份运行的临时 unit：由 systemd 读文件设 env，凭据不会出现在 ps 的
      # 命令行里，也不需要 sudo 的 --preserve-env。
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "tgdl-login" ''
          set -eu
          if [ "$(id -u)" -ne 0 ]; then
            echo "需要 root：sudo tgdl-login" >&2
            exit 1
          fi
          ${pkgs.coreutils}/bin/install -d -o ${user} -g ${user} -m 0750 ${stateDir}
          exec ${pkgs.systemd}/bin/systemd-run --pty --quiet --collect \
            --unit=tgdl-login \
            --uid=${user} --gid=${user} --working-directory=${stateDir} \
            --property=EnvironmentFile=${envFile} \
            ${lib.getExe nur.tgdl} -cmd login -config ${configFile}
        '')
      ];
    };
}
