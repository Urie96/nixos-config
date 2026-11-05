{
  flake.nixosModules.lldap =
    { config, pkgs, ... }:
    let
      # nixpkgs 的 lldap 模块用 DynamicUser，uid 每次启动都变，所以 secret
      # 不能靠文件属主（owner）下发，只能走 systemd credentials：
      # 源文件 root 可读即可，systemd 会把副本放进 /run/credentials/lldap.service。
      credentialsDir = "/run/credentials/lldap.service";
      vars = config.clan.core.vars.generators.lldap;
    in
    {
      # key-seed / jwt-secret 和密码拆成两个 generator：改密码时不会连带轮换
      # key-seed（轮换 key-seed 会让库里所有已有的 OPAQUE 密码记录失效）。
      # key-seed 决定密码记录的加密，必须和 users.db 一起备份。
      clan.core.vars.generators.lldap = {
        files.key-seed = { };
        files.jwt-secret = { };
        runtimeInputs = with pkgs; [
          coreutils
          openssl
        ];
        script = ''
          openssl rand -hex 32 | tr -d '\n' > "$out/key-seed"
          openssl rand -hex 32 | tr -d '\n' > "$out/jwt-secret"
        '';
      };

      # bootstrap 管理员（ldap_user_dn = admin）的密码。随机生成，随时能
      # `clan vars get home-server lldap-password/admin-password` 取回来，
      # 相当于一个永远找得回的 break-glass 凭据。
      # lldap 只在空库时创建这个账号；之后每次启动按 force_ldap_user_pass_reset
      # 把密码重置成这里的值。
      #
      # 注意密码长度：lldap 默认策略要求至少 8 个字符，不足会直接 panic
      # （Minimum password length is 8 characters）而不是报个清楚的错。
      # base64 24 字节 = 32 字符，安全。
      clan.core.vars.generators.lldap-password = {
        files.admin-password = { };
        runtimeInputs = with pkgs; [
          coreutils
          openssl
        ];
        script = ''
          openssl rand -base64 24 | tr -d '\n' > "$out/admin-password"
        '';
      };

      # authelia 的服务账号（uid=authelia）的 bind 密码。机对机专用，人不使用。
      # 注意：lldap 的 force_ldap_user_pass_reset 只管 bootstrap 账号，所以
      # **轮换这里的密码必须同时在 lldap UI 里改一次**，否则 authelia bind 失败。
      clan.core.vars.generators.lldap-service = {
        files.bind-password = { };
        runtimeInputs = with pkgs; [
          coreutils
          openssl
        ];
        script = ''
          openssl rand -base64 24 | tr -d '\n' > "$out/bind-password"
        '';
      };

      services.lldap = {
        enable = true;
        # 单机用默认 sqlite，库文件在 /var/lib/lldap/users.db。
        database.type = "sqlite";

        environment = {
          LLDAP_KEY_SEED_FILE = "${credentialsDir}/key-seed";
          LLDAP_JWT_SECRET_FILE = "${credentialsDir}/jwt-secret";
          LLDAP_LDAP_USER_PASS_FILE = "${credentialsDir}/admin-password";
        };

        settings = {
          ldap_base_dn = "dc=lubui";
          # lldap 只在数据库为空时创建这一个初始账号，名字由这里决定。
          # 用它当 break-glass 管理员（密码在 clan vars 里，永远取得回）；
          # 日常账号和人用的组都在 web UI 里建。
          # 注意：DB 一旦非空，改这个值不会新建/改名任何账号；而且如果库里
          # 没有这个名字的用户，启动时的密码重置会直接 fatal 退出。
          ldap_user_dn = "admin";
          ldap_user_email = "admin@lubui.com";
          # 只给本机 nginx / authelia 用，不对外暴露端口。
          ldap_host = "127.0.0.1";
          http_host = "127.0.0.1";
          # 用于 lldap 自己发出的密码重置链接。
          http_url = "https://lldap.lubui.com:8443";
          # admin 密码以 clan vars 为准：每次启动都按 credential 重置，
          # 所以在 web UI 里改密码不会生效（改 vars 才行）。
          # 注意这个重置是「硬失败」：如果库里已经非空但没有 ldap_user_dn
          # 指定的那个用户（比如 DB 里还是旧的 admin），lldap 会直接
          # `Error: while resetting admin password` 并以 status=1 退出。
          # 这时要么清掉 DB 让它重新初始化，要么手工把该用户建出来。
          force_ldap_user_pass_reset = "always";
        };
      };

      systemd.services.lldap.serviceConfig.LoadCredential = [
        "key-seed:${vars.files.key-seed.path}"
        "jwt-secret:${vars.files.jwt-secret.path}"
        "admin-password:${config.clan.core.vars.generators.lldap-password.files.admin-password.path}"
      ];

      # 这个 vhost 故意不挂 authelia 的 forward-auth：lldap 的 UI 有自己的
      # 登录，挂了只会变成「先登 authelia 再登 lldap」两次登录。
      # 代价：lldap 的登录框是这里唯一直接暴露在 8443 上的密码入口。
      # 好处：authelia 挂了 / bind 失败时，还能从这里进 lldap 修账号。
      services.nginx.virtualHosts."lldap.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.lldap.settings.http_port}";
          proxyWebsockets = true;
        };
      };
    };
}
