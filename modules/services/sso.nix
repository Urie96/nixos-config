{
  flake.nixosModules.sso =
    { config, pkgs, ... }:
    let
      html = pkgs.fetchurl {
        url = "https://gist.github.com/Urie96/c78fd950cad774f171a06da466ba07d1/raw/41471ccfab5ed56ad334002a58583d2c04165706/nginx-sso.html";
        hash = "sha256-Na4/ddcxnimTrgkG911JRxx7BpXUc5JquyGNAg1E5yM=";
      };

      sso = pkgs.runCommand "nginx-sso" { meta.mainProgram = "nginx-sso"; } ''
        mkdir -p $out/share/frontend
        cp -R ${html} $out/share/frontend/index.html
        ln -s ${pkgs.nginx-sso}/bin $out/bin
      '';
    in
    {

      clan.core.vars.generators.nginx_sso = {
        files.basic_auth.owner = "nginx";
        files.cookie_key.owner = "nginx";
        runtimeInputs = with pkgs; [
          apacheHttpd
          openssl
          gnused
        ];
        prompts.password.description = "Password for nginx sso";
        script = ''
          htpasswd -BbnC 10 "" "$(cat $prompts/password)" | tr -d ':\n' | sed 's/$2y/$2a/' > $out/basic_auth
          openssl rand -base64 48 > $out/cookie_key
        '';
      };

      services.nginx.sso = {
        enable = true;
        package = sso;
        configuration = {
          listen = {
            addr = "0.0.0.0";
            port = 8082;
          };
          login = {
            default_redirect = "https://home.lubui.com:8443";
            title = "家庭服务器登录";
            default_method = "simple";
            names.simple = "用户名/密码";
            hide_mfa_field = true;
          };
          cookie = {
            domain = ".lubui.com";
            expire = 60 * 60 * 24 * 30;
            authentication_key._secret = config.clan.core.vars.generators.nginx_sso.files.cookie_key.path;
          };
          providers.simple = {
            users.urie._secret = config.clan.core.vars.generators.nginx_sso.files.basic_auth.path;
            enable_basic_auth = true;
          };
          audit_log = {
            events = [
              "access_denied"
              "login_success"
              "login_failure"
              "logout"
              "validate"
            ];
            headers = [
              "x-origin-uri"
              "x-host"
            ];
            targets = [
              "fd://stdout"
            ];
            trusted_ip_headers = [
              "X-Forwarded-For"
              "RemoteAddr"
              "X-Real-IP"
            ];
          };
          acl.rule_sets = [
            {
              rules = [
                {
                  field = "x-host";
                  regexp = ".*";
                }
              ];
              allow = [ "urie" ];
            }
          ];
        };
      };

      services.nginx.virtualHosts."sso.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.nginx.sso.configuration.listen.port}";
          proxyWebsockets = true;
        };
      };
    };
}
