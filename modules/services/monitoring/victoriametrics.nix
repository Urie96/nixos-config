{
  flake.nixosModules.victoriametrics =
    { ... }:
    {
      services.victoriametrics = {
        enable = true;

        # 单机模式，只监听回环地址：查询/写入都不直接对外，
        # 需要 Grafana 或手动看时走 Grafana 数据源或 `ssh -L 8428:127.0.0.1:8428`
        listenAddress = "127.0.0.1:8428";
        retentionPeriod = "30d";
        extraOptions = [ "-loggerLevel=WARN" ];

        prometheusConfig.scrape_configs = [
          {
            # ./telegraf.nix 在这里暴露 lubui.com 的
            # http_response / x509_cert 指标
            job_name = "telegraf";
            scrape_interval = "60s";
            static_configs = [
              {
                targets = [ "127.0.0.1:9273" ];
              }
            ];
          }
          {
            # VictoriaMetrics 自身指标（抓取队列、存储、查询错误等）
            job_name = "victoriametrics";
            scrape_interval = "60s";
            static_configs = [
              {
                targets = [ "127.0.0.1:8428" ];
              }
            ];
          }
        ];
      };
    };
}
