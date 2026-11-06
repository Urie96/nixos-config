{ self, ... }:
{
  flake.nixosModules.monitoring = {
    imports = with self.nixosModules; [
      uptime-kuma
      telegraf
      victoriametrics
      vmalert
      alertmanager
      monitoring-srvos-rules
      grafana
    ];
  };
}
