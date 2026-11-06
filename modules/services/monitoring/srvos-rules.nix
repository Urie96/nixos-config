{
  # 只为了拿 srvos.prometheus.ruleGroups（默认的 Http / CertExpiry / TelegrafDown 等告警），
  # 指标存储和规则求值仍然走 VictoriaMetrics + vmalert，不跑 Prometheus server。
  flake.nixosModules.monitoring-srvos-rules =
    {
      lib,
      self,
      ...
    }:
    {
      imports = [ self.inputs.srvos.nixosModules.roles-prometheus ];

      services.prometheus.enable = false;

      srvos.prometheus.ruleGroups.srvosAlerts.alertRules = {
        # 这几条依赖 Prometheus server / Promtail 自己的指标，这套栈里没有，关掉
        PrometheusNotConnectedToAlertmanager.enable = false;
        PrometheusRuleEvaluationFailures.enable = false;
        PrometheusTemplateExpansionFailures.enable = false;
        PromtailRequestsErrors.enable = false;
        PromtailFileLagging.enable = false;

        # 默认 7 天，留出续期时间改成 14 天（对所有 x509_cert 探针生效）
        # CertExpiry = {
        #   expr = lib.mkForce ''x509_cert_expiry{type="leaf"} < 14*24*3600'';
        #   annotations.description = lib.mkForce ''{{$labels.instance}}: The TLS certificate from {{$labels.source}} will expire in less than 14 days: {{$value}}s'';
        # };
      };
    };
}
