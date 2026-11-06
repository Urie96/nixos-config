{
  flake.nixosModules.memos =
    { config, pkgs, ... }:
    let
      memosUrl = "https://memos.lubui.com:8443";
      # authelia 的 OIDC 端点（memos 不支持 discovery，必须手写三个 URL）
      autheliaUrl = config.my.authelia.url;
      # memos 0.31 的部署配置文件路径是硬编码的，不能换目录。
      idpFile = "/etc/secrets/memos-idp-authelia.json";
      gen = config.clan.core.vars.generators.memos-oidc;
    in
    {
      # OIDC 客户端凭据。明文给 memos（必须写进 /etc/secrets 的 JSON），
      # pbkdf2 摘要给 authelia（它的 YAML 只收摘要）。
      clan.core.vars.generators.memos-oidc = {
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

      my.authelia.oidcClients = [
        {
          client_id = "memos";
          client_name = "Memos";
          client_secret = gen.files.client-secret-hash.value;
          public = false;
          # memos 用 golang.org/x/oauth2 的 AuthStyleAutoDetect 换 token，
          # client_secret_post 是 authelia 官方 memos 集成示例里的写法。
          token_endpoint_auth_method = "client_secret_post";
          # memos 前端固定发 S256 challenge（IdentityProviderButtons.tsx），
          # 而 authelia 的 pkce_challenge_method 默认值是 plain，不改这里会在
          # 授权阶段报 invalid code challenge method。不强制 PKCE，只是为了
          # 兼容老版本 memos。
          require_pkce = false;
          pkce_challenge_method = "S256";
          redirect_uris = [ "${memosUrl}/auth/callback" ];
          scopes = [
            "openid"
            "profile"
            "email"
          ];
          # 家里没开 TOTP；以后强制二次验证改成 "two_factor"
          authorization_policy = "one_factor";
          id_token_signed_response_alg = "RS256";
          access_token_signed_response_alg = "none";
          # memos 直接 GET /api/oidc/userinfo 并当 JSON 解析，必须是未签名的
          userinfo_signed_response_alg = "none";
        }
      ];

      services.memos = {
        enable = true;

        # 这些是 nixpkgs 模块的 default 值。之所以全部重写一遍：`settings` 是
        # 带 default 的普通 option，一旦我们自己定义它，default 就整体失效
        # （少写 MEMOS_DATA 会让 memos 去 /var/opt/memos 建一个空库 = 丢数据）。
        # 只改最后一项：默认的 http://localhost:5230 会让分享链接/RSS 指向本机。
        settings = {
          MEMOS_MODE = "prod";
          MEMOS_ADDR = "127.0.0.1";
          MEMOS_PORT = "5230";
          MEMOS_DATA = config.services.memos.dataDir;
          MEMOS_DRIVER = "sqlite";
          MEMOS_INSTANCE_URL = memosUrl;
        };
      };

      # memos 只认 /etc/secrets/memos-idp-<label>.json，而且 0.31 不支持
      # ${env:...}/${file:...} 引用（那是 26.10 的 declarative config），
      # 所以 clientSecret 只能以明文出现在文件里 → 不能是 nix store 里的文件，
      # 只能运行时写出来。
      #
      # 权限有两个坑：
      #   1. memos 单元开了 PrivateUsers，root:root 0600 的文件在它的 user
      #      namespace 里属于 nobody，读不到 → 必须 chown 给 memos。
      #   2. 文件含明文 secret，权限给 0400。
      systemd.services.memos-oidc-config = {
        description = "Write memos OAuth2 identity-provider file";
        wantedBy = [ "multi-user.target" ];
        before = [ "memos.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          LoadCredential = [ "client-secret:${gen.files.client-secret.path}" ];
        };
        script = ''
          set -euo pipefail
          install -d -m 0750 -o root -g ${config.services.memos.group} /etc/secrets
          umask 077
          cat > ${idpFile} <<EOF
          {
            "uid": "authelia",
            "name": "Authelia",
            "type": "OAUTH2",
            "identifierFilter": "",
            "config": {
              "oauth2Config": {
                "clientId": "memos",
                "clientSecret": "$(cat "$CREDENTIALS_DIRECTORY/client-secret")",
                "authUrl": "${autheliaUrl}/api/oidc/authorization",
                "tokenUrl": "${autheliaUrl}/api/oidc/token",
                "userInfoUrl": "${autheliaUrl}/api/oidc/userinfo",
                "scopes": [
                  "openid",
                  "profile",
                  "email"
                ],
                "fieldMapping": {
                  "identifier": "preferred_username",
                  "displayName": "name",
                  "email": "email"
                }
              }
            }
          }
          EOF
          chown ${config.services.memos.user}:${config.services.memos.group} ${idpFile}
          chmod 0400 ${idpFile}
        '';
      };

      systemd.services.memos = {
        after = [ "memos-oidc-config.service" ];
        wants = [ "memos-oidc-config.service" ];
      };

      services.nginx.virtualHosts."memos.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:5230";
          proxyWebsockets = true;
        };
      };
    };
}
