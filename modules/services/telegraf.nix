{
  flake.nixosModules.telegraf =
    { ... }:
    {
      services.telegraf = {
        enable = true;

        extraConfig = {
          agent = {
            interval = "60s";
            flush_interval = "60s";
          };

          inputs = {
            # 常用的查询（VictoriaMetrics UI 或 Grafana 里）：
            #   x509_cert_expiry{type="leaf",host="lubui.com"} / 86400   # 证书剩余天数
            #   http_response_result_code{host="lubui.com"}              # 0 = 请求成功
            #   http_response_response_time{host="lubui.com"}            # 响应耗时（秒）

            # 网站可用性：状态码 200 且请求能完成才算 result_code == 0
            http_response = [
              {
                urls = [ "https://lubui.com/" ];
                response_status_code = 200;
                response_timeout = "10s";
                tags.host = "lubui.com";
              }
            ];

            # TLS 证书剩余有效期，单位秒
            x509_cert = [
              {
                sources = [ "https://lubui.com:443" ];
                timeout = "10s";
                tags.host = "lubui.com";
              }
            ];

            # telegraf 自身的采集/写入健康度，便于排查探针不工作时是探测失败还是 agent 卡住
            internal = { };
          };

          # 只监听本机，由同机的 VictoriaMetrics 来拉；不对外暴露
          outputs.prometheus_client = {
            listen = "127.0.0.1:9273";
            metric_version = 2;
          };
        };
      };
    };
}
