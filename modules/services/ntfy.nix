{
  flake.nixosModules.ntfy =
    { ... }:
    {
      services.ntfy-sh = {
        enable = true;
        settings = {
          base-url = "https://ntfy.lubui.com:8443";
          listen-http = ":3112";
          # 反代后面必须开 behind-proxy，否则所有访客共享 nginx 一个 IP 的限流配额
          # （实测 visitors=1，手机订阅被 429 打死；开后可区分真实访客 IP）
          behind-proxy = true;
          # 私有服务：默认 60 burst/5s 补 1 对个人推送太紧，调大
          visitor-request-limit-burst = 5000;
          visitor-request-limit-replenish = "1s";
        };
      };

      services.nginx.virtualHosts."ntfy.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:3112";
          # 注意：不要开 proxyWebsockets —— 它会注入 `Connection: $connection_upgrade`，
          # 对无 Upgrade 的普通请求解析为 `Connection: close`，导致长轮询流被截断（实测空 body）
          # 手动指定：HTTP/1.1 上游（keepalive/chunked 必需）+ 清空 Connection 头 + 关缓冲
          extraConfig = ''
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_buffering off;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };
      };
    };
}
