{
  flake.nixosModules.stash =
    {
      config,
      pkgs,
      ...
    }:
    {
      clan.core.vars.generators.stash = {
        files.password = { };
        files.jwt_key = { };
        files.session_key = { };
        prompts.password.persist = true;
        runtimeInputs = with pkgs; [ openssl ];
        script = ''
          openssl rand -hex 32 >$out/jwt_key
          openssl rand -hex 32 >$out/session_key
        '';
      };

      services.stash = {
        enable = true;
        username = "urie";
        passwordFile = config.clan.core.vars.generators.stash.files.password.path;
        jwtSecretKeyFile = config.clan.core.vars.generators.stash.files.jwt_key.path;
        sessionStoreKeyFile = config.clan.core.vars.generators.stash.files.session_key.path;
        mutablePlugins = false;
        mutableScrapers = false;
        # false：每次启动都按下面的 settings 重新生成 /var/lib/stash/config.yml。
        # 这样 host 之类才真正生效；代价是 UI 里改的配置重启后会被覆盖回来，
        # 想长期保留的选项必须写进下面的 settings。
        mutableSettings = false;
        settings = {
          # 只给本机 nginx 反代用；0.0.0.0 会让局域网直连 9999 绕开 authelia。
          host = "127.0.0.1";
          port = 9999;
          sound_on_preview = true;
          autostart_video = true;
          continue_playlist_default = true;
          # 侧边栏只显示这两项（UI 里自定义过菜单）。
          menu_items = [
            "scenes"
            "performers"
          ];
          language = "zh-CN";
          stash = [
            { path = "/var/lib/stash/files"; }
          ];
          ffmpeg.hardware_acceleration = true;
          security_tripwire_accessed_from_public_internet = null;
          dangerous_allow_public_without_auth = true;

          # 下面是 2026-11-06 从 live config.yml 抄过来的非默认项。
          # preview_*/blobs_*/database/generated 等未列出的值都等于模块默认值。
          plugins.package_sources = [ ];
          scrapers.package_sources = [ ];

          ui.advancedMode = true;
          ui.lastNoteSeen = 20251026;
          # Scan/Generate 对话框的默认勾选项。
          ui.taskDefaults = {
            scan = {
              rescan = false;
              scanGenerateClipPreviews = true;
              scanGenerateCovers = true;
              scanGenerateImagePreviews = true;
              scanGeneratePhashes = false;
              scanGeneratePreviews = true;
              scanGenerateSprites = false;
              scanGenerateThumbnails = false;
            };
            generate = {
              clipPreviews = true;
              covers = true;
              imagePreviews = true;
              markers = true;
              phashes = true;
              previews = true;
              sprites = false;
              # 0 / 0 表示生成时使用上面的 preview_segments 等全局默认值。
              previewOptions = {
                previewPreset = "slow";
                previewSegmentDuration = 0;
                previewSegments = 0;
              };
            };
          };
        };
      };
      systemd.tmpfiles.rules = [
        "d /var/lib/stash/files 0770 stash stash -"
      ];

      services.nginx.virtualHosts."stash.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        # 公网可达（WAN 开了 8443），入口先过 authelia。
        # stash 没有 auth.proxy 这种信任反代头的机制，所以这里只挡门不传身份；
        # 配合下面“允许无认证访问”就是单点登录效果（进门的人不再输 stash 密码）。
        extraConfig = config.my.authelia.nginxSsoConfig;

        locations = {
          "/authelia" = {
            extraConfig = config.my.authelia.nginxVerifyLocation;
          };
          "/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.stash.settings.port}";
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
    };
}
