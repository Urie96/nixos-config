{
  flake.nixosModules.authelia =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.authelia;
    in
    {
      options.my.authelia = {
        url = lib.mkOption {
          type = lib.types.str;
          default = "https://auth.lubui.com:8443";
          description = ''
            Authelia 门户的外部 URL。必须带端口：session cookie 的 `domain`
            不能带端口，但 `authelia_url` 必须和浏览器实际访问的 origin 一致。
          '';
        };

        nginxForwardAuth = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = ''
            放在 vhost 的 server 级 `extraConfig` 里的 forward-auth 片段。
            配合下面的 `/authelia` location 使用。
          '';
          default = ''
            auth_request /authelia;
            error_page 401 =302 ${cfg.url}/?rd=$scheme://$http_host$request_uri;
          '';
        };

        nginxVerifyLocation = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = ''
            鉴权子请求的 internal location 内容，必须挂在 `/authelia` 这个 location 上。
          '';
          default = ''
            internal;
            proxy_pass http://127.0.0.1:9091/api/verify;

            # 鉴权子请求不能带 body
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
            proxy_set_header Connection "";

            # authelia 只接受 https/wss scheme，且必须有 X-Original-URL
            proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
            proxy_set_header X-Original-Method $request_method;
            proxy_set_header X-Forwarded-Method $request_method;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-Uri $request_uri;
            proxy_set_header X-Forwarded-For $remote_addr;

            proxy_connect_timeout 5s;
            proxy_send_timeout 5s;
            proxy_read_timeout 5s;
          '';
        };
      };

      config = {
        # Vars generator for authelia secrets
        clan.core.vars.generators.authelia = {
          files.jwt-secret.owner = "authelia-main";
          files.storage-encryption-key.owner = "authelia-main";
          files.session-secret.owner = "authelia-main";
          files.users-database.owner = "authelia-main";

          runtimeInputs = with pkgs; [
            coreutils
            openssl
            gnused
          ];

          prompts.password.description = "Password for Authelia user urie";
          prompts.password.type = "hidden";

          script = ''
            gensecret() {
              openssl rand 64 | openssl base64 -A | tr '+/' '-_' | tr -d '='
            }
            gensecret > "$out/jwt-secret"
            gensecret > "$out/storage-encryption-key"
            gensecret > "$out/session-secret"

            password_hash="$(${pkgs.authelia}/bin/authelia crypto hash generate argon2 --password "$(cat "$prompts/password")" --no-confirm | sed -n 's/^Digest: //p')"
            cat > "$out/users-database" <<EOF
            users:
              urie:
                disabled: false
                displayname: urie
                password: "$password_hash"
                email: lubui.com@gmail.com
                groups:
                  - admin
            EOF
          '';
        };

        services.authelia.instances.main = {
          enable = true;
          secrets = {
            jwtSecretFile = config.clan.core.vars.generators.authelia.files.jwt-secret.path;
            storageEncryptionKeyFile =
              config.clan.core.vars.generators.authelia.files.storage-encryption-key.path;
            sessionSecretFile = config.clan.core.vars.generators.authelia.files.session-secret.path;
          };

          settings = {
            theme = "dark";

            authentication_backend.file.path =
              config.clan.core.vars.generators.authelia.files.users-database.path;
            access_control.default_policy = "one_factor";

            session = {
              expiration = "1h"; # 不勾「记住我」时 cookie 的有效期。会被活动滚动续期，不是"登录后总共只能活 1h"
              inactivity = "12h"; # 空闲超时：两次「有活动」之间的最大间隔。超了就销毁 session，要重新登录。每次授权的请求都会刷新它
              remember_me = "1M"; # 勾了「记住我」时用的有效期，直接替代 expiration。设成 -1 可以整个禁用「记住我」
              cookies = [
                {
                  domain = "lubui.com";
                  authelia_url = cfg.url;
                  default_redirection_url = "https://home.lubui.com:8443";
                }
              ];
            };

            storage.local.path = "/var/lib/authelia-main/db.sqlite3";
            notifier.filesystem.filename = "/var/lib/authelia-main/notifications.txt";
          };
        };

        services.nginx.virtualHosts."auth.lubui.com" = {
          addSSL = true;
          useACMEHost = "lubui.com";

          locations."/" = {
            proxyPass = "http://127.0.0.1:9091";
            proxyWebsockets = true;
          };
        };
      };
    };
}
