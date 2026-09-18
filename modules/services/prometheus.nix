{
  flake.nixosModules.prometheus =
    { config, ... }:
    let
      cfg = config.services.prometheus.exporters;
    in
    {
      services.prometheus = {
        enable = true;
        globalConfig.scrape_interval = "10s"; # "1m"
        scrapeConfigs = [
          {
            job_name = "node";
            static_configs = [
              {
                targets = [ "localhost:${toString cfg.node.port}" ];
              }
            ];
          }
        ];
      };
      services.prometheus.exporters.node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        extraFlags = [
          "--collector.ethtool"
          "--collector.softirqs"
          "--collector.tcpstat"
          "--collector.wifi"
        ];
      };
    };
}
