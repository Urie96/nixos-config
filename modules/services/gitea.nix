# gitea 查看镜像github仓库的token：sudo cat /var/lib/gitea/repositories/urie/nixos-config.git/config
{ self, ... }:
{
  flake.nixosModules.gitea =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      giteaUrl = "https://git.lubui.com:8443";
      # gitea 的 OAuth2 登录源存在数据库里，app.ini 的 [oauth2_client] 只是全局调参
      # （自动注册、账号合并、取哪个 claim 当用户名），所以源本身只能用 CLI 建。
      #
      # 回调 URL 是 ROOT_URL + "/user/oauth2/" + 源名字 + "/callback"，
      # 改这里的名字必须同步改下面 authelia 客户端里的 redirect_uris。
      oidcSourceName = "authelia";
      oidcCallback = "${giteaUrl}/user/oauth2/${oidcSourceName}/callback";
      gen = config.clan.core.vars.generators.gitea-oidc;
      # CLI 必须显式给 --config：它默认去读编译期的 app.ini 路径，
      # 而实例的真正配置在 customDir/conf/app.ini。
      giteaCli = "${lib.getExe config.services.gitea.package} --config ${config.services.gitea.customDir}/conf/app.ini";
    in
    {
      # OIDC 客户端凭据：明文给 gitea（它会存进自己的数据库），
      # pbkdf2 摘要给 authelia（它的 YAML 只收摘要）。
      clan.core.vars.generators.gitea-oidc = {
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
          client_id = "gitea";
          client_name = "Gitea";
          client_secret = gen.files.client-secret-hash.value;
          public = false;
          # gitea 用 golang.org/x/oauth2 自动探测客户端认证方式：先试 HTTP Basic，
          # 所以保持 authelia 的默认 client_secret_basic 最省事。
          token_endpoint_auth_method = "client_secret_basic";
          # gitea 目前不发 PKCE（goth 的 openidConnect provider 没实现），
          # 但把方法定成 S256：将来它加上了也不会因为 authelia 默认的 plain 而失败。
          require_pkce = false;
          pkce_challenge_method = "S256";
          redirect_uris = [ oidcCallback ];
          scopes = [
            "openid"
            "profile"
            "email"
          ];
          # 家里没开 TOTP；以后强制二次验证改成 "two_factor"
          authorization_policy = "one_factor";
          id_token_signed_response_alg = "RS256";
          access_token_signed_response_alg = "none";
          # gitea 直接 GET userinfo 当 JSON 解析，必须是未签名的
          userinfo_signed_response_alg = "none";
        }
      ];

      services.gitea = {
        enable = true;
        settings.log.LEVEL = "Error";
        # 没有注册入口，首次装完要手动建管理员：
        #   GITEA=$(systemctl cat gitea | sed -n 's|^ExecStart=\(.*/bin/gitea\) .*|\1|p' | tail -1)
        #   sudo -u gitea env GITEA_WORK_DIR=/var/lib/gitea "$GITEA" admin user create \
        #     --admin --username <name> --email <mail>
        settings.service.DISABLE_REGISTRATION = true;
        # settings.metrics.ENABLED = true;
        settings.server = {
          DISABLE_ROUTER_LOG = true;
          ROOT_URL = giteaUrl;
          # Gitea >= 1.26 defaults this to "auto", which builds absolute URLs
          # from the request's Host header. nginx's `$host` drops the :8443
          # port, so clone/PR/API links came out as https://git.lubui.com/...
          # "never" keeps using ROOT_URL as the authoritative public URL.
          PUBLIC_URL_DETECTION = "never";
          PROTOCOL = "http+unix";
          DISABLE_SSH = true;
        };
        settings.security = {
          # DISABLE_GIT_HOOKS = false;
        };

        # OIDC 登录源的行为调参（源本身由下面的 preStart 建）。
        settings."oauth2_client" = {
          # 第一次用 OIDC 登录时自动建号
          ENABLE_AUTO_REGISTRATION = true;
          # 已经存在的本地账号（比如 urie）按**邮箱**自动关联，避免多出一个
          # 同名新号。前提是 lldap 里这个人的 mail 和 gitea 账号的邮箱一致。
          ACCOUNT_LINKING = "auto";
          # 拿 preferred_username 当 gitea 用户名（authelia 的 OIDC 里它等于
          # lldap 的 uid）。默认值是 nickname，依赖 provider 的 nickname claim。
          USERNAME = "preferred_username";
        };
      };

      systemd.services.gitea = {
        # 明文 secret 不能进 nix store（会写进 app.ini 之外的数据库），
        # 所以走 systemd credentials：root 读 clan var，再拷给 gitea 用户读。
        serviceConfig.LoadCredential = [
          "oidc-client-secret:${gen.files.client-secret.path}"
        ];

        # 幂等维护登录源。为什么不删了重建：源在数据库里有自增 ID，删掉再加会
        # 换 ID，已经关联过的外部登录记录会失联，用户得重新点一遍。
        preStart = lib.mkAfter ''
          oidc_source_id=$(${giteaCli} admin auth list | ${pkgs.gawk}/bin/awk -F'\t' '$2 == "${oidcSourceName}" { print $1; exit }')
          oidc_args=(
            --name ${oidcSourceName}
            --provider openidConnect
            --key gitea
            --secret "$(cat "$CREDENTIALS_DIRECTORY/oidc-client-secret")"
            --auto-discover-url ${config.my.authelia.url}/.well-known/openid-configuration
            --scopes openid --scopes profile --scopes email
            --full-name-claim-name name
          )
          if [[ -n "$oidc_source_id" ]]; then
            ${giteaCli} admin auth update-oauth --id "$oidc_source_id" "''${oidc_args[@]}"
          else
            ${giteaCli} admin auth add-oauth "''${oidc_args[@]}"
          fi
        '';
      };

      services.nginx.virtualHosts."git.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";
        locations."/".proxyPass = "http://unix:${config.services.gitea.settings.server.HTTP_ADDR}:/";
      };

    };

  flake.sysModules.gitea = { lib, ... }: {
    imports = [
      "${self.inputs.nixpkgs.outPath}/nixos/modules/services/misc/gitea.nix"
      self.sysModules.postgresql
    ];

    # system-manager 没有 mysql 模块，这里只声明一个空壳 option。
    # 真要用 mysql 得换成导入 nixpkgs 的 mysql 模块。
    options.services.mysql = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        system-manager 上的占位 option：gitea 模块无条件往 services.mysql 写定义，
        没有这个声明就没法求值。不要在 devbox 上依赖它做任何事。
      '';
    };

  };

}
