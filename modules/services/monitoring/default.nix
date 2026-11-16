{ self, ... }:
{
  flake.nixosModules.monitoring = {
    imports = with self.nixosModules; [
      # uptime-kuma
      telegraf
      victoriametrics
      vmalert
      # nixbot 的 /metrics 抓取 + 失败告警规则（依赖 vmalert）
      nixbot-metrics
      alertmanager
      monitoring-srvos-rules
      grafana
    ];
  };
}
