{
  flake.nixosModules.vmalert =
    { config, ... }:
    {
      services.vmalert.instances.metrics = {
        enable = true;

        settings = {
          "datasource.url" = "http://127.0.0.1:8428";
          "remoteWrite.url" = "http://127.0.0.1:8428";
          "notifier.url" = [ "http://127.0.0.1:9093" ];
          "httpListenAddr" = "127.0.0.1:8880";
          "evaluationInterval" = "60s";

          # srvos 默认规则（monitoring-srvos-rules 生成）：
          # 每个 http_response 序列一条 Http 告警、每个 x509_cert 序列一条 CertExpiry，
          # 所以加网站只需要在 telegraf 里加探针，不用再写规则。
          "rule" = config.services.prometheus.ruleFiles;
        };

        # 只放 srvos 没覆盖的“探针整体没数据”规则。
        # 注意 vmalert 规则文件格式是 `groups:`（nixpkgs 模块文档里的 `group:` 示例是错的）。
        rules.groups = [
          {
            name = "probe-health";
            rules = [
              {
                alert = "HttpProbeMissing";
                expr = "absent(http_response_result_code)";
                for = "15m";
                labels.severity = "warning";
                annotations.summary = "HTTP 探针没有数据";
                annotations.description = "telegraf 的 http_response 探针超过 15 分钟没有上报，检查 telegraf/VM 抓取。";
              }
              {
                alert = "CertProbeMissing";
                expr = "absent(x509_cert_expiry)";
                for = "15m";
                labels.severity = "warning";
                annotations.summary = "TLS 证书探针没有数据";
                annotations.description = "telegraf 的 x509_cert 探针超过 15 分钟没有上报，检查 telegraf/VM 抓取。";
              }
            ];
          }
        ];
      };

      # VictoriaMetrics 本身不算规则；配了这个 flag 后它的 /vmalert/ 才会
      # 反向代理到上面这个 vmalert 实例，否则打开 /vmalert/ 会报
      # "the '-vmalert.proxyURL' command-line must be configured"
      services.victoriametrics.extraOptions = [
        "-vmalert.proxyURL=http://127.0.0.1:8880"
      ];
    };
}
