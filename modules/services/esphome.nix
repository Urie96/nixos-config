{
  flake.nixosModules.esphome =
    {
      config,
      lib,
      ...
    }:
    let
      data_path = "/var/lib/docker-esphome";
    in
    {
      virtualisation.oci-containers.containers.esphome = {
        image = "esphome/esphome:latest";
        environment = {
          TZ = config.time.timeZone;
          ESPHOME_LOG_LEVEL = "WARNING";
        };

        volumes = [
          "${data_path}:/config"
        ];

        # volumes = [ "/var/lib/docker-esphome:/config" ];
        extraOptions = [
          "--network=host"
        ];
      };

      systemd.tmpfiles.rules = [
        "d ${data_path} 0700 urie users -"
      ];

      services.nginx.virtualHosts."esphome.lubui.com" =
        assert lib.assertMsg config.services.nginx.sso.enable "sso must be enabled";
        {
          addSSL = true;
          useACMEHost = "lubui.com";

          extraConfig = ''
            auth_request /sso-auth;
            error_page 401 = @error401;
          '';

          locations = {
            "/" = {
              # 不要动这里，这个顺序刚好是一个稳态
              proxyPass = "http://127.0.0.1:6052";
              recommendedProxySettings = false;
              extraConfig = ''
                proxy_ignore_client_abort   off;
                proxy_read_timeout          86400s;
                proxy_redirect              off;
                proxy_send_timeout          86400s;
                proxy_max_temp_file_size    0;

                proxy_set_header Accept-Encoding "";
                proxy_set_header Connection $connection_upgrade;
                proxy_set_header Host $host:$server_port;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-NginX-Proxy true;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header Authorization "";
              '';
            };
            "/sso-auth" = {
              priority = 11;
              extraConfig = ''
                internal;
                proxy_pass_request_body off;
                proxy_set_header Content-Length "";
                proxy_pass http://127.0.0.1:${toString config.services.nginx.sso.configuration.listen.port}/auth;
                # Set custom information for ACL matching: Each one is available as
                # a field for matching: X-Host = x-host, ...
                proxy_set_header X-Origin-URI $request_uri;
                proxy_set_header X-Host $http_host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
            "@error401" = {
              priority = 1;
              extraConfig = ''
                return 302 https://sso.lubui.com:8443/login?go=$scheme://$http_host$request_uri;
              '';
            };
          };
        };
    };
}
