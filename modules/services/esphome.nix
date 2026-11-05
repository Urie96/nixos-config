{
  flake.nixosModules.esphome =
    {
      config,
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

      services.nginx.virtualHosts."esphome.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        extraConfig = config.my.authelia.nginxForwardAuth;

        locations = {
          "/" = {
            # 不要动这里，这个顺序刚好是一个稳态
            proxyPass = "http://127.0.0.1:6052";
            recommendedProxySettings = false;
            extraConfig = ''
              # 给后端透传登录用户（$upstream_http_* 在子请求之外是空的，
              # 必须先用 auth_request_set 取出来）
              auth_request_set $authelia_user $upstream_http_remote_user;
              auth_request_set $authelia_email $upstream_http_remote_email;
              proxy_set_header X-Forwarded-User $authelia_user;
              proxy_set_header X-Forwarded-Email $authelia_email;

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
          "/authelia" = {
            priority = 11;
            extraConfig = config.my.authelia.nginxVerifyLocation;
          };
        };
      };
    };
}
