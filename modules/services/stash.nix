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
        mutablePlugins = true;
        mutableScrapers = true;
        settings = {
          # 只给本机 nginx 反代用；0.0.0.0 会让局域网直连 9999 绕开 authelia。
          host = "127.0.0.1";
          sound_on_preview = true;
          language = "zh-CN";
          stash = [
            { path = "/var/lib/stash/files"; }
          ];
          ffmpeg.hardware_acceleration = true;
          security_tripwire_accessed_from_public_internet = null;
          dangerous_allow_public_without_auth = true;
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
