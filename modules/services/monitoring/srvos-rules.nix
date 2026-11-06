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

        # 这几条在这台机器上永远不会有数据（硬件/软件堆不存在），留着只会让人
        # 误以为有覆盖。真要哪天上了 RAID/ZFS 再放开：
        Ext4Errors.enable = false; # 根是 btrfs
        ZfsErrors.enable = false;
        ZpoolErrors.enable = false;
        MdRaidDegradedDisks.enable = false; # 没有用软 RAID
        PostfixQueueLength.enable = false; # 没跑 postfix
        NfsExportNotPresent.enable = false; # 没跑 nfs server
        # 下面几条依赖 srvos 自带的 telegraf exec 探针 / healthchecks.io 导出器，
        # 我们只用 srvos 的规则、没用它的 telegraf mixin：
        Ipv6DadCheck.enable = false; # ipv6_dad_failures_count
        SecureDnsQuery.enable = false; # secure_dns_state
        Healthchecks.enable = false; # hc_check_up
        # TaskFailed / DailyTaskNotRun / TenMinutesTaskNotRun 先留着：
        # 以后用 task_last_run{name,state,frequency} 这个约定发指标时它们会自动生效。

        # srvos 自带 systemd_units_active_code == 3 的告警（for 2m），
        # 采集侧在 telegraf.nix 的 inputs.systemd_units。这里只把文案换成中文并加 severity，
        # 表达式保持原样（name!~"user@<uid>.service"：用户 manager 实例失败是常态，不告）：
        #
        #   systemd_units_active_code{name!~"user@\d+.service"} == 3
        SystemdServiceFailed = {
          labels.severity = "critical";
          annotations.summary = "systemd 单元处于 failed 状态";
          annotations.description = lib.mkForce "{{$labels.host}} 上的 {{$labels.name}} 启动失败（active=failed，已持续 2 分钟以上），看 journalctl -u {{$labels.name}}";
        };

        # 默认 7 天，留出续期时间改成 14 天（对所有 x509_cert 探针生效）
        # CertExpiry = {
        #   expr = lib.mkForce ''x509_cert_expiry{type="leaf"} < 14*24*3600'';
        #   annotations.description = lib.mkForce ''{{$labels.instance}}: The TLS certificate from {{$labels.source}} will expire in less than 14 days: {{$value}}s'';
        # };
      };
    };
}
