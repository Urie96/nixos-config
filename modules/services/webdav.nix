{
  flake.nixosModules.webdav =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      services.nginx = {
        package = pkgs.nginx.override {
          modules = with pkgs.nginxModules; [
            moreheaders
            dav
          ];
        };
        appendHttpConfig = ''
          dav_ext_lock_zone zone=webdav:10m; 
        '';
      };

      clan.core.vars.generators.webdav = {
        prompts.username.description = "Username for webdav";
        prompts.password.description = "Password for webdav";
        files.http_auth.owner = "nginx";
        runtimeInputs = with pkgs; [ apacheHttpd ];
        script = ''
          htpasswd -n -B -b "$(cat $prompts/username)" "$(cat $prompts/password)" > $out/http_auth
        '';
      };

      services.nginx.virtualHosts."dav.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";
        http2 = false;
        extraConfig = ''
          ssl_ecdh_curve secp384r1;
        '';
        basicAuthFile = config.clan.core.vars.generators.webdav.files.http_auth.path;

        locations."/" = {
          root = "/var/lib/nginx/webdav";
          extraConfig = ''
            dav_access user:rw group:r all:r;
            create_full_put_path on; #启用完整的创建目录支持，默认情况下，Put 方法只能在已存在的目录里创建文件
            charset utf-8;
            autoindex on;
            autoindex_localtime on;
            autoindex_exact_size off;

            #为各种方法的URI后加上斜杠，解决各平台webdav客户端的兼容性问题
            set $dest $http_destination;
            if (-d $request_filename) {
              rewrite ^(.*[^/])$ $1/;
              set $dest $dest/;
            }

            if ($request_method ~ (MOVE|COPY)) {
              more_set_input_headers 'Destination: $dest';
            }

            if ($request_method ~ MKCOL) {
              rewrite ^(.*[^/])$ $1/ break;
            }

            #支持所有方法
            dav_methods PUT DELETE MKCOL COPY MOVE;
            dav_ext_methods PROPFIND OPTIONS LOCK UNLOCK;
            dav_ext_lock zone=webdav;
          '';
        };
      };

      # systemd ProtectSystem=strict 下 /var 默认只读，放行 webdav 目录
      systemd.services.nginx.serviceConfig.ReadWritePaths = [
        "/var/lib/nginx/webdav"
      ];

      # 确保 webdav 目录存在且属主为 nginx
      systemd.tmpfiles.settings."10-webdav" = {
        "/var/lib/nginx/webdav".d = {
          mode = "0755";
          user = "nginx";
          group = "nginx";
        };
      };
    };
}
