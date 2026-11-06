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

          # systemd 单元监控的补充规则。
          # “单元进入 failed 状态” 那条来自 srvos 默认规则（SystemdServiceFailed，
          # 在 srvos-rules.nix 里覆盖文案），采集侧在 telegraf.nix 的 inputs.systemd_units。
          # 这里只补 srvos 没覆盖的两种：
          #   - 崩溃循环：Restart= 会被 systemd 一直拉起，active 状态反复在
          #     activating/active 之间跳，永远不会停在 failed，所以 failed 那条抓不到
          #   - 采集本身挂了：没有数据时所有规则都安静地不报
          {
            name = "systemd";
            rules = [
              {
                alert = "SystemdServiceRestartLoop";
                # systemd_units_restarts 只有 details=true 的那条（service）输入才有，
                # 所以这里不用按 .service 过滤（要写正则反而得用 \\.，PromQL 字符串走 Go 转义）
                expr = "changes(systemd_units_restarts[15m]) > 3";
                for = "5m";
                labels.severity = "warning";
                annotations.summary = "systemd 服务在崩溃循环";
                annotations.description = "{{$labels.host}} 上的 {{$labels.name}} 15 分钟内重启超过 3 次，看 journalctl -u {{$labels.name}}。";
              }
              {
                alert = "SystemdUnitsProbeMissing";
                expr = "absent(systemd_units_active_code)";
                for = "15m";
                labels.severity = "warning";
                annotations.summary = "systemd 单元指标没有数据";
                annotations.description = "telegraf 的 systemd_units 输入超过 15 分钟没有上报，检查 telegraf 服务是否正常（systemctl status telegraf）以及它能不能读 system bus。";
              }
              {
                # failed 的挂载单元已经被上面的 SystemdServiceFailed 覆盖，
                # 这里补“没失败但根本不在挂载状态”的情况：/mnt/* 都是 nofail 挂的，
                # 盘不在线时 unit 可能直接 inactive，备份会静默跳过（见 btrbk.nix 的注释）。
                alert = "MountUnitInactive";
                expr = ''systemd_units_active_code{name=~"mnt-.*\\.mount"} == 2'';
                for = "10m";
                labels.severity = "warning";
                annotations.summary = "外挂盘没有挂载";
                annotations.description = "{{$labels.host}} 上的 {{$labels.name}} 处于 inactive，对应的盘可能不在线（nofail 挂载不会阻塞启动），依赖它的备份/数据服务会静默跳过。";
              }
            ];
          }

          # 硬件层。srvos 的 SmartErrors 只看 SMART 的 overall-health 位
          # （很多盘坏到一半它还是 PASSED），这里补真正在恶化的属性：
          #   5   = Reallocated_Sector_Ct（已重映射扇区）
          #   197 = Current_Pending_Sector（待定扇区，任何非 0 就该查盘）
          #   198 = Offline_Uncorrectable（不可纠正扇区）
          # 需要 telegraf.nix 里 inputs.smart.attributes = true。
          {
            name = "hardware";
            rules = [
              {
                alert = "SmartAttributeDegrading";
                expr = ''smart_attribute_raw_value{id=~"5|197|198"} > 0'';
                for = "10m";
                labels.severity = "critical";
                annotations.summary = "磁盘 SMART 属性异常";
                annotations.description = "{{$labels.device}} 的 {{$labels.name}}（id={{$labels.id}}）raw_value={{$value}}，说明已出现重映射/待定/不可纠正扇区，尽快备份并考虑换盘。";
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
