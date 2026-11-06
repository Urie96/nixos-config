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

        backend = lib.mkOption {
          type = lib.types.enum [
            "file"
            "ldap"
          ];
          default = "ldap";
          description = ''
            账号后端。`file` 是写死在 clan vars 生成出来的 YAML 里；`ldap` 走 lldap。

            切换顺序不能反：先把 lldap 部署起来、确认 urie 已经在里面，再把这里
            改成 `ldap` 并部署。反过来做的话 authelia 启动时 bind 不到账号，
            会直接以 fatal 退出并反复重启。
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

        # 带身份的 forward-auth：跟 nginxForwardAuth 一样挂在 vhost 的 server 级
        # extraConfig，但把 authelia /api/verify 响应里的 Remote-User /
        # Remote-Groups 取出来存成 nginx 变量，供 nginxSsoUserHeaders 透传给后端。
        #
        # 单挂这个只解决「挡住没登录的人」；要让下游真的免登录，后端得自己信任
        # 这些头（例如 grafana 的 auth.proxy），否则用户还是会被问第二遍密码。
        nginxSsoConfig = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = ''
            带身份的 forward-auth 片段，放在 vhost 的 server 级 `extraConfig` 里。
            配合 `/authelia` location + `nginxSsoUserHeaders` 使用。
          '';
          default = ''
            auth_request /authelia;
            auth_request_set $authelia_user $upstream_http_remote_user;
            auth_request_set $authelia_groups $upstream_http_remote_groups;
            auth_request_set $authelia_email $upstream_http_remote_email;
            auth_request_set $authelia_name $upstream_http_remote_name;
            error_page 401 =302 ${cfg.url}/?rd=$scheme://$http_host$request_uri;
          '';
        };

        # 必须放在 location 里而不是 server 级：location 自己写了 proxy_set_header
        # （recommendedProxySettings 就会写）之后，server 级的 proxy_set_header
        # 会被整体覆盖，头就丢了。
        #
        # 没跑 auth_request 的 location 里这两个变量是空字符串，等于传给下游一个
        # 空头 —— 这是防伪造的关键，不要图省事直接手写成用户名。
        nginxSsoUserHeaders = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = ''
            需要身份的 location 里的 `proxy_set_header` 片段，配合 `nginxSsoConfig`。
          '';
          default = ''
            proxy_set_header Remote-User $authelia_user;
            proxy_set_header Remote-Groups $authelia_groups;
            proxy_set_header Remote-Email $authelia_email;
            proxy_set_header Remote-Name $authelia_name;
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
          files = {
            jwt-secret.owner = "authelia-main";
            storage-encryption-key.owner = "authelia-main";
            session-secret.owner = "authelia-main";
          }
          # 用户库只在 file 后端下存在；ldap 后端下账号归 lldap 管。
          // lib.optionalAttrs (cfg.backend == "file") {
            users-database.owner = "authelia-main";
          };

          runtimeInputs = with pkgs; [
            coreutils
            openssl
            gnused
          ];

          prompts = lib.optionalAttrs (cfg.backend == "file") {
            password.description = "Password for Authelia user urie";
            password.type = "hidden";
          };

          script = ''
            gensecret() {
              openssl rand 64 | openssl base64 -A | tr '+/' '-_' | tr -d '='
            }
            gensecret > "$out/jwt-secret"
            gensecret > "$out/storage-encryption-key"
            gensecret > "$out/session-secret"
          ''
          + lib.optionalString (cfg.backend == "file") ''
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

          # LDAP 的 bind 密码不能写进 settings（会进 nix store），走 _FILE。
          # 用专用服务账号 uid=authelia（不是你的个人账号）：这样改自己的密码不会
          # 把 authelia 弄挂，它泄露了也不在 lldap_admin 里。
          # 注意：轮换 lldap-service/bind-password 后必须同时去 lldap UI 改密码，
          # 因为 force_ldap_user_pass_reset 只作用于 bootstrap 账号。
          #
          # 跟 jwt/storage/session 一样走 systemd credentials：clan 生成的 var
          # 是 root:root 0400，authelia 服务用户根本没权限读，只有 systemd 在
          # 启动时以 root 把它拷进 %d 才能拿到。（lldap 那边也是这个机制。）
          environmentVariables = lib.mkIf (cfg.backend == "ldap") {
            AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = "%d/ldapPasswordFile";
          };

          settings = {
            theme = "dark";

            authentication_backend =
              if cfg.backend == "ldap" then
                {
                  ldap = {
                    implementation = "lldap";
                    address = "ldap://127.0.0.1:3890";
                    base_dn = config.services.lldap.settings.ldap_base_dn;
                    # 专用服务账号，不是你的个人账号：改自己密码不会影响它，
                    # 它也不在 lldap_admin 里。需要加进 lldap_password_manager 组，
                    # 门户里的「修改密码」才能改到别人。
                    user = "uid=authelia,ou=people,dc=lubui";

                    # username 是 authelia 里绑身份用的键：session、TOTP、
                    # passkey、OIDC sub 都按它存，定下之后不要再改。
                    # lldap 的默认 users_filter 同时匹配 uid 和 mail，所以这里
                    # 用 uid 当身份，登录时仍然可以输邮箱。
                    attributes = {
                      username = "uid";
                      display_name = "cn";
                      mail = "mail";
                    };
                  };
                }
              else
                {
                  file.path = config.clan.core.vars.generators.authelia.files.users-database.path;
                };

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

        # 注意这行必须在 services.authelia.instances.main 外面，否则会变成
        # instances.main.systemd.* 把整棵树搞坏。
        systemd.services.authelia-main.serviceConfig.LoadCredential = lib.mkIf (cfg.backend == "ldap") (
          lib.mkAfter [
            "ldapPasswordFile:${config.clan.core.vars.generators.lldap-service.files.bind-password.path}"
          ]
        );

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
