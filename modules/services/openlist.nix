{
  flake.nixosModules.openlist =
    {
      config,
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
      # OIDC 客户端凭据：明文给 OpenList（UI 里粘一次），pbkdf2 摘要给 authelia。
      # 摘要标 `secret = false` 才能在求值时读进 authelia 的 YAML（不可逆，不能拿来认证）。
      clan.core.vars.generators.openlist-oidc = {
        files.client-secret = { };
        files.client-secret-hash.secret = false;
        runtimeInputs = with pkgs; [
          coreutils
          openssl
          gnused
        ];
        script = ''
          openssl rand -hex 32 | tr -d '\n' > "$out/client-secret"
          ${pkgs.authelia}/bin/authelia crypto hash generate pbkdf2 --variant sha512 \
            --password "$(cat "$out/client-secret")" |
            sed 's/^Digest: //' > "$out/client-secret-hash"
        '';
      };

      # OpenList 4.x 有通用 OIDC driver（sso_login_platform = "OIDC"，走 go-oidc
      # discovery + JWKS 验签），但它的 SSO 设置存在别处：不在 config.json，而在
      # 数据库 settings 表（x_settings，键名来自 internal/conf/const.go）。所以这
      # 里只声明 authelia 侧，OpenList 侧在网页里配一次：
      #
      #   Settings -> SSO：
      #     Enabled                开
      #     Login platform         OIDC
      #     Endpoint               https://auth.lubui.com:8443
      #                            （go-oidc 的 issuer，必须与 authelia 的 authelia_url
      #                             完全一致，不能带 .well-known、不能带尾斜杠）
      #     Client ID              openlist
      #     Client Secret          `clan vars get home-server openlist-oidc/client-secret`
      #     OIDC username key      preferred_username（默认 name 是 lldap 的 cn 显示名）
      #     Auto register          先关！第一次登录用 /@manage 里的「绑定」把现有
      #                            admin 账号绑上，否则会新建一个普通用户
      #     Compatibility mode     关（打开会把 token 放 ?token= 的 URL 里，进 access log）
      #
      # 以后重建库要重填这些值（它不在 config.json 里，nix 管不到）。
      #
      # redirect_uris 带 query 参数是必须的：authelia 用的是简单字符串比较
      # （BestPracticeURIComparisonStrategy），OpenList 非兼容模式的回调就是
      # /api/auth/sso_callback?method=…；地址由 config.json 的 site_url 拼出来，
      # 上面已经设成 https://openlist.lubui.com:8443，所以两边能对上。
      my.authelia.oidcClients = [
        {
          client_id = "openlist";
          client_name = "OpenList";
          client_secret = config.clan.core.vars.generators.openlist-oidc.files.client-secret-hash.value;
          public = false;
          # OpenList 的 oauth2 库是 AuthStyleAutoDetect，先试 basic
          token_endpoint_auth_method = "client_secret_basic";
          # OpenList 不发 PKCE
          require_pkce = false;
          redirect_uris = [
            "https://openlist.lubui.com:8443/api/auth/sso_callback?method=sso_get_token"
            "https://openlist.lubui.com:8443/api/auth/sso_callback?method=get_sso_id"
          ];
          scopes = [
            "openid"
            "profile"
          ];
          authorization_policy = "one_factor";
          id_token_signed_response_alg = "RS256";
          userinfo_signed_response_alg = "none";
        }
      ];

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
