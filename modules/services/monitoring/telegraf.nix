{
  flake.nixosModules.telegraf = {
    services.telegraf = {
      enable = true;

      extraConfig = {
        agent = {
          interval = "60s";
          flush_interval = "60s";
        };

        inputs = {
          # 常用的查询（VictoriaMetrics UI 或 Grafana 里）：
          #   x509_cert_expiry{type="leaf",site="lubui.com"} / 86400   # 证书剩余天数
          #   http_response_result_code{site="lubui.com"}              # 0 = 请求成功
          #   http_response_response_time{site="lubui.com"}            # 响应耗时（秒）
          #
          # 注意 interval **不要**写成小时级：telegraf 不会在启动时先采一次，
          # 第一个采样点要等满一个 interval 才出现（实测 6h 的插件启动 8s 后指标数是 0）。
          # 而且 prometheus_client 只把指标缓存在内存里，telegraf 一重启，
          # 稀疏指标就从 /metrics 里消失，直到下次采集 —— 看板上就是一个大洞。
          # 所以采集一律用分钟级，想降采样放到 VictoriaMetrics 那边做。

          # 网站可用性：状态码 200 且请求能完成才算 result_code == 0
          #
          # 一个 [[inputs.http_response]] = 一个探针实例，tags.site 就是 Grafana 里
          # 站点面板的分组维度（看板用 label_values(http_response_result_code, site)
          # 自动发现站点，加网站只要在这里加一段）。
          # 不要把一个实例的 urls 写成多个站点：那样所有站点共用同一个 site tag，
          # 只剩 server tag 能区分，max by (site) 会把它们压成一条。
          #
          # 站点维度刻意用 site 而不是 host：telegraf 默认会把 host 设成主机名，
          # 复用 host 会让同一 label 里混进两种语义（站点名和机器名）。
          http_response = [
            {
              urls = [ "https://lubui.com/" ];
              response_status_code = 200;
              response_timeout = "10s";
              interval = "60s";
              tags.site = "lubui.com";
            }
            {
              urls = [ "https://home.lubui.com:8443" ];
              response_status_code = 200;
              response_timeout = "10s";
              interval = "60s";
              tags.site = "home.lubui.com";
            }
          ];

          # TLS 证书剩余有效期，单位秒
          # 证书一天才变一次，1h 足够；同步周期越长，重启后的空窗越大。
          x509_cert = [
            {
              sources = [ "https://lubui.com:443" ];
              timeout = "10s";
              interval = "1h";
              tags.site = "lubui.com";
            }
            {
              sources = [ "https://home.lubui.com:8443" ];
              timeout = "10s";
              interval = "1h";
              tags.site = "home.lubui.com";
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
