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
        #
        # 这里的“没数据”一律用 absent_over_time，不要用 absent：
        # absent 看的是瞬时查询结果，而 VM 对瞬时查询的 staleness 窗口远小于
        # 这里的采样间隔（实测：x509_cert 10 分钟一采，`absent(x509_cert_expiry)`
        # 一小时里按 60s 取 55 个点全是 1，只有刚采完那一瞬间才变成 0）。
        # 于是规则会在 1/0 之间来回跳、`for` 永远攒不满，界面上就是一条永远
        # pending 的告警；换成 absent_over_time 直接看存储里有没有样本，
        # 跟瞬时可见性无关，窗口给到两个采样周期以上就稳定了。
        rules.groups = [
          {
            name = "probe-health";
            rules = [
              {
                alert = "HttpProbeMissing";
                # http_response 60s 一采，10m 窗口 = 连续漏了 10 次
                expr = "absent_over_time(http_response_result_code[10m])";
                for = "10m";
                labels.severity = "warning";
                annotations.summary = "HTTP 探针没有数据";
                annotations.description = "telegraf 的 http_response 探针超过 20 分钟没有上报（窗口 10m + for 10m），检查 telegraf/VM 抓取。";
              }
              {
                alert = "CertProbeMissing";
                # x509_cert 10m 一采，窗口得比两个周期长；telegraf 重启后
                # 本来就要等满一个 interval 才有第一个点，别让重启触发误报
                expr = "absent_over_time(x509_cert_expiry[30m])";
                for = "15m";
                labels.severity = "warning";
                annotations.summary = "TLS 证书探针没有数据";
                annotations.description = "telegraf 的 x509_cert 探针超过 45 分钟没有上报（窗口 30m + for 15m），检查 telegraf/VM 抓取。";
              }
            ];
          }

          # 域名注册到期。采集侧是 telegraf.nix 的 inputs.whois（WHOIS，6h 一次）。
          #
          # 用绝对时间戳 whois_expiration_timestamp 而不是 whois_expiry：
          # expiry 是采样那一刻算出来的秒数，6h 的采样间隔意味着最多偏 6h；
          # 时间戳与采样时刻无关，任何时候算都是准的。
          #
          # 查询/解析失败时 telegraf 要么根本不吐指标、要么吐 0（status=unknown），
          # 所以两条到期规则都要求 `> 0`，失败不会伪装成“快到期”，由下面两条单独报。
          #
          # 都套一层 last_over_time[8h] 取“最近一次已知值”：采集间隔是 6h，
          # 直接用瞬时值依赖 VM 的 auto staleness（按采样间隔中位数估），
          # 而 telegraf 重启后本来就会有最长 6h 的空窗。8h 窗口让告警穿过这段空窗。
          #
          # `- time()` 写在 and 左边是有意的：`a and b` 只保留 a 的元素，
          # 这样告警里的 {{$value}} 是“剩余秒数”，而不是时间戳。
          {
            name = "domain";
            rules = [
              {
                alert = "DomainExpiringIn30Days";
                expr = "last_over_time(whois_expiration_timestamp[8h]) - time() < 30*86400 and last_over_time(whois_expiration_timestamp[8h]) > 0";
                for = "1h";
                labels.severity = "warning";
                annotations.summary = "域名 {{$labels.domain}} 不到 30 天到期";
                annotations.description = "{{$labels.domain}} 的注册有效期只剩 {{$value}} 秒（< 30 天），去注册商续费。域名掉线会连 DNS、邮件和所有子域一起没。";
              }
              {
                alert = "DomainExpiringIn7Days";
                expr = "last_over_time(whois_expiration_timestamp[8h]) - time() < 7*86400 and last_over_time(whois_expiration_timestamp[8h]) > 0";
                for = "10m";
                labels.severity = "critical";
                annotations.summary = "域名 {{$labels.domain}} 不到 7 天到期";
                annotations.description = "{{$labels.domain}} 只剩 {{$value}} 秒（< 7 天），可能已经过了注册商的正常续费窗口，马上处理。";
              }
              {
                alert = "WhoisExpiryUnknown";
                # telegraf 查到了数据但没解出到期日（.com 以外的 WHOIS 格式千奇百怪）。
                # 这种时候到期规则全哑，必须单独报。
                expr = "last_over_time(whois_expiration_timestamp[8h]) == 0";
                # 7h ≈ 一个采样周期 + 1h：等于“连续两次采样都解不出来”才报
                for = "7h";
                labels.severity = "warning";
                annotations.summary = "域名 {{$labels.domain}} 的到期时间解析不出来";
                annotations.description = "whois 返回了数据但解析不出 expiration date（status={{$labels.status}}），看 journalctl -u telegraf | grep whois。";
              }
              {
                alert = "WhoisMetricMissing";
                # 6h 的采集间隔 + telegraf 重启后的空窗，所以窗口给到 24h：
                # 短时间的空窗是正常的，持续没数据才是 whois 插件/网络坏了。
                expr = "absent_over_time(whois_expiration_timestamp[24h])";
                for = "1h";
                labels.severity = "warning";
                annotations.summary = "域名到期监控没有数据";
                annotations.description = "telegraf 的 whois 输入 24 小时没上报过 whois_expiration_timestamp，检查 telegraf 日志和本机能不能连 whois:43。";
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
                expr = "absent_over_time(systemd_units_active_code[10m])";
                for = "10m";
                labels.severity = "warning";
                annotations.summary = "systemd 单元指标没有数据";
                annotations.description = "telegraf 的 systemd_units 输入超过 20 分钟没有上报（窗口 10m + for 10m），检查 telegraf 服务是否正常（systemctl status telegraf）以及它能不能读 system bus。";
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
          # （很多盘坏到一半它还是 PASSED），这里补真正在恶化的属性。
          #
          # 注意两个标定：
          #   - 重映射扇区（id 5）**不能**用 > 0 当阈值：home-server 那块 4T 盘
          #     已经跑了 2 万多小时，raw=1 是正常的磨损，不是故障。所以这条看
          #     “24 小时内还在涨”，而不是绝对值。
          #   - 待定/不可纠正扇区（197/198）任何非 0 都值得看，用窗口内最大值，
          #     这样也顶得住机械盘休眠导致的序列中断（telegraf 默认
          #     nocheck=standby，盘睡了就不出数据）。
          # 需要 telegraf.nix 里 inputs.smart.attributes = true。
          {
            name = "hardware";
            rules = [
              {
                alert = "SmartPendingSectors";
                expr = ''max_over_time(smart_attribute_raw_value{id=~"197|198"}[3h]) > 0'';
                for = "1h";
                labels.severity = "critical";
                annotations.summary = "磁盘出现待定/不可纠正扇区";
                annotations.description = "{{$labels.device}} 的 {{$labels.name}}（id={{$labels.id}}）= {{$value}}，3 小时内出现过非 0 值。数据可能已经读不出来了，先把 btrbk 备份跑一遍再去查盘。";
              }
              {
                alert = "SmartReallocatedGrowing";
                # 不要用 delta()/increase()：机械盘休眠 + series 消失会让 VictoriaMetrics
                # 的增量函数算出幻觉值（实测一块恒为 1 的 series，delta(...[24h]) 返回 1）。
                # max_over_time 和 min_over_time 各自取窗口内真实样本的最值，不受中断影响。
                expr = ''max_over_time(smart_attribute_raw_value{id="5"}[24h]) > min_over_time(smart_attribute_raw_value{id="5"}[24h])'';
                for = "1h";
                labels.severity = "warning";
                annotations.summary = "磁盘重映射扇区在增长";
                annotations.description = "{{$labels.device}} 的 Reallocated_Sector_Ct 24 小时内不再是恒定值（当前值看 smart_attribute_raw_value{id=\"5\"}）。绝对值不大时不用慌，但要开始关注并确保 btrbk 备份可恢复。";
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
