{ self, ... }:
{
  flake.nixosModules.nixbot =
    {
      config,
      ...
    }:
    {
      imports = [
        self.inputs.nixbot.nixosModules.nixbot
      ];

      # GitHub App 凭据由 clan vars 声明，再经 sops 部署到机器：
      #   nixbot-github/app-secret-key  GitHub App 设置页生成的私钥（PEM 原样保存）
      #   nixbot-github/oauth-secret    GitHub App 的 OAuth client secret
      #   nixbot-github/webhook-secret  GitHub App 的 Webhook secret（两边填同一个值）
      #
      # 首次生成：clan vars generate home-server -g nixbot-github
      # 轮换：clan vars set home-server nixbot-github/app-secret-key
      #   （粘贴新值后再 clan vars generate home-server -g nixbot-github）
      clan.core.vars.generators.nixbot-github = {
        prompts.app-secret-key = {
          description = "GitHub App 私钥（PEM），在 GitHub App 设置页生成后粘贴";
          type = "multiline";
          persist = true;
        };
        prompts.oauth-secret = {
          description = "GitHub App 的 OAuth client secret";
          type = "hidden";
          persist = true;
        };
        prompts.webhook-secret = {
          description = "GitHub App 的 Webhook secret，需与 GitHub App 设置页填写的一致";
          type = "hidden";
          persist = true;
        };
        # persist 会自动创建 files.<name>，这里只补 restartUnits：
        # secret 轮换后由 sops-nix 重启 nixbot 重新消费。
        files.app-secret-key.restartUnits = [ "nixbot.service" ];
        files.oauth-secret.restartUnits = [ "nixbot.service" ];
        files.webhook-secret.restartUnits = [ "nixbot.service" ];
      };

      services.nixbot = {
        enable = true;
        # domain 在这个模块里被当成「对外 base URL」用（OAuth 的 redirect_uri、
        # webhook URL、same_origin 校验都取它），而本机 nginx 的 SSL 监听是
        # 8443，所以对外 URL 必须带端口。
        domain = "nixbot.lubui.com:8443";
        # 让 baseUrl 变成 https://，同时 cookie 才会带 Secure。
        useHTTPS = true;
        # 不能用模块自带的 nginx 生成 vhost：它把 domain 原样当作
        # virtualHosts 的 key / server_name，而 nginx 在匹配 server_name 之前
        # 会把 Host 头和已配置名字里的端口都剥掉（只有 ListenStream 用端口），
        # 于是 server_name "nixbot.lubui.com:8443" 永远匹配不到，请求会落到
        # 默认 vhost。所以 vhost 在下面手写（纯域名 + lubui.com 的 ACME 证书），
        # 代价是 nixbot 改为监听 127.0.0.1:8010 而不是 unix socket。
        nginx.enable = false;
        port = 8010;
        # Users in this list are allowed to trigger builds and change settings.
        # Entries are provider-qualified: "github:<login>", "gitea:<login>",
        # "oidc:<issuer>:<username>".
        admins = [ "github:Urie96" ];
        github = {
          enable = true;
          appId = 5529037;
          oauthId = "Iv23liQKamz0u9MaIy8U"; # OAuth client id
          # 私钥、webhook secret、OAuth secret 都是 clan vars 声明并加密存放的，
          # path 最终指向 sops-nix 的 /run/secrets/...，由 nixbot 的 LoadCredential 读取。
          appSecretKeyFile = config.clan.core.vars.generators.nixbot-github.files.app-secret-key.path;
          webhookSecretFile = config.clan.core.vars.generators.nixbot-github.files.webhook-secret.path;
          oauthSecretFile = config.clan.core.vars.generators.nixbot-github.files.oauth-secret.path;
          # All repositories with this topic will be built.
          topic = "nixbot-lubui";
        };

        # Gitea example.
        # gitea = {
        #   enable = true;
        #   instanceUrl = "https://git.clan.lol";
        #   tokenFile = "/var/lib/secrets/gitea-token";
        #   oauthId = "aaaaaaaaaaaaaaaaaaaa";
        #   oauthSecretFile = "/var/lib/secrets/gitea-oauth-secret";
        #   topic = "build-with-buildbot";
        # };

        buildSystems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        # Optional nix-eval-jobs settings.
        evalWorkerCount = 2; # limit the number of concurrent evaluation workers
        evalMaxMemorySize = 4096; # per-worker memory limit in MiB

        # By default only default branches build. Additional branches:
        # branches = {
        #   releaseBranches.matchGlob = "release-*";
        # };

        # Generic OIDC login example.
        # oidc = {
        #   enable = true;
        #   name = "Provider Name";
        #   discoveryUrl = "https://id.thalheim.io/.well-known/openid-configuration";
        #   clientId = "aaaaaaaaaaaaaaaaaaaa";
        #   clientSecretFile = "/var/lib/secrets/oidc-secret";
        # };

        # Allow unauthenticated users to cancel and restart builds, e.g.
        # behind a VPN where network access implies trust.
        # allowUnauthenticatedControl = true;

        # Trust a username header set by an authenticating reverse proxy.
        # The proxy MUST set or strip this header on every request. Users
        # appear as "proxy:<name>", e.g. admins = [ "proxy:alice" ];
        # proxyAuthHeader = "X-Remote-User";

        # Local PostgreSQL over the unix socket is provisioned by default.
        # Remote database instead:
        # database.createLocally = false;
        # database.urlFile = "/var/lib/secrets/db-url"; # postgresql://user:pass@host/db

        # Request a TLS certificate for the nginx virtual host (recommended).
        # nginx.enableACME = true;
      };

      services.nginx.virtualHosts."nixbot.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.nixbot.port}";
          extraConfig = ''
            # GitHub webhook 载荷上限 25 MB，nginx 默认 1m。
            client_max_body_size 25m;
            proxy_connect_timeout 120s;
            proxy_send_timeout 120s;
            # 日志页走 SSE，长连接不能被读超时或缓冲掐断。
            proxy_read_timeout 3600s;
            proxy_buffering off;
          '';
        };
      };
    };
}
