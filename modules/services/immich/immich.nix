{
  flake.nixosModules.immich =
    { config, pkgs, ... }:
    let
      # immich 的系统配置基线：`GET /api/system-config` 的原始输出（也可以在
      # Administration -> Settings 里导出），整份放在 immich-config.json。
      #
      # 为什么必须整份：immich 的 buildConfig（server/src/utils/config.ts）在设置了
      # IMMICH_CONFIG_FILE 之后**完全不读数据库**，只做「文件 + 默认值」合并 ——
      # 文件里少一个键，那个键就回落默认值。半份配置 = 静默重置其余所有系统设置。
      # 代价是网页里的 Administration -> Settings 会变成只读，或完全由这个文件决定。
      #
      # 升级 immich 后新增了配置项：在新版本里重新导出一份、覆盖这个文件即可
      # （导出里没有的键在新版本里会回落到默认值，所以别只截改动部分）。
      exported = builtins.fromJSON (builtins.readFile ./immich-config.json);
    in
    {
      # OIDC 客户端凭据。一份给 immich（明文，由下面 settings 的 `_secret` 在
      # 启动时注入到 /run/immich/config.json），一份给 authelia（pbkdf2 摘要，
      # 写进它的 YAML）。
      #
      # 摘要标成 `secret = false` 是刻意的：它是不可逆的，单独拿到也没法认证，
      # 而 authelia 要求客户端 secret 以摘要形式写在配置里，所以只能让它在求值
      # 阶段可读（clan 会把它落到 vars/per-machine/<machine>/immich-oidc/
      # client-secret-hash/value，跟着仓库走）。生成后要 git add。
      clan.core.vars.generators.immich-oidc = {
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

      # immich 的 OIDC 客户端。redirect_uris 来自 immich 文档：
      #   /auth/login     网页登录
      #   /user-settings  网页里「手动关联账号」
      #   /api/oauth/mobile-redirect  手机 App 的中转（见下面的 Mobile Override）
      # 不直接注册 app.immich:///oauth-callback：那是自定义 scheme，走 https
      # 中转更稳（authelia 只对 http/https 做校验最省事）。
      my.authelia.oidcClients = [
        {
          client_id = "immich";
          client_name = "Immich";
          client_secret = config.clan.core.vars.generators.immich-oidc.files.client-secret-hash.value;
          public = false;
          # immich 默认 tokenEndpointAuthMethod = client_secret_post
          token_endpoint_auth_method = "client_secret_post";
          # immich 会带 S256 challenge，但「强制」PKCE 只会在客户端不带时报错，
          # 所以这里声明方法、不强制。
          require_pkce = false;
          pkce_challenge_method = "S256";
          redirect_uris = [
            "https://immich.lubui.com:8443/auth/login"
            "https://immich.lubui.com:8443/user-settings"
            "https://immich.lubui.com:8443/api/oauth/mobile-redirect"
          ];
          scopes = [
            "openid"
            "profile"
            "email"
          ];
          # 家里没开 TOTP；以后想强制二次验证改成 "two_factor"。
          authorization_policy = "one_factor";
          id_token_signed_response_alg = "RS256";
          # immich 的 profileSigningAlgorithm 默认 none（不签 userinfo），
          # 跟它对齐，否则 immich 会拒收 userinfo。
          userinfo_signed_response_alg = "none";
        }
      ];

      services.immich = {
        enable = true;
        host = "0.0.0.0";
        machine-learning.environment.HF_ENDPOINT = "https://hf-mirror.com";

        # 导出的基线 + OAuth 覆盖。
        #
        # clientSecret 用 `_secret`：nixpkgs 模块会在 preStart 里用 jq 从
        # systemd credential 读出内容写进 /run/immich/config.json，明文不进
        # nix store，也不进这个文件。
        settings = exported // {
          oauth = exported.oauth // {
            enabled = true;
            # authelia >= 4.38 的 issuer 等于 session cookie 的 authelia_url
            issuerUrl = config.my.authelia.url;
            clientId = "immich";
            clientSecret = {
              _secret = config.clan.core.vars.generators.immich-oidc.files.client-secret.path;
            };
            autoRegister = true;
            # 先关掉自动跳转：万一 redirect_uri / issuer 配错，还能从登录页用
            # 本地密码进来救急（要跳过自动跳转也可以用 /auth/login?autoLaunch=0）。
            # 整套流程验证过之后再改成 true。
            autoLaunch = false;
            # 手机 App 用 https 中转，避免依赖 app.immich:// 这种自定义 scheme
            mobileOverrideEnabled = true;
            mobileRedirectUri = "https://immich.lubui.com:8443/api/oauth/mobile-redirect";
            # lldap 里没有 preferred_username 这个 claim，用 uid
            storageLabelClaim = "uid";
          };
        };
      };

      services.nginx.virtualHosts."immich.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.immich.port}";
          proxyWebsockets = true;
        };
      };
    };
}
