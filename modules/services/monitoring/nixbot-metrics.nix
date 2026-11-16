{
  # nixbot 的失败告警：VictoriaMetrics 直接抓 nixbot 自己的 /metrics，
  # 规则进现有的 vmalert → alertmanager → alertmanager-ntfy → 手机 链路。
  #
  # 为什么直接抓而不是走 telegraf：nixbot 本来就是 Prometheus 文本端点
  # （web/metrics.py），本机回环抓一次就完事，telegraf 中转只是多一跳。
  #
  # 为什么“失败”一律写成 delta()：nixbot_builds / nixbot_effects 是
  # 「按状态分组的历史累计条数」（effect_runs 表保留 90 天），只增不减。
  # 直接写 `{status="failed"} > 0` 一旦响过就永久 firing、永不恢复，等于没告警。
  # delta(...[1h]) > 0 的语义是「最近一小时里新增了失败」，最后一次失败过去
  # 一小时后自动恢复。60s 的采样密度下 delta 是可靠的；行被 90 天保留期清掉时
  # delta 变负，也不会误报。
  #
  # 注意 /metrics **故意不带项目/任务名**（未鉴权端点，按状态聚合，
  # 见 web/metrics.py 顶部注释），所以这里只能告到「哪一类失败了」。
  # 具体是哪个任务 / 哪台机器，要打开 https://nixbot.lubui.com:8443/ 看。
  # 想精确到任务名得另接 effect_runs 表（这次不做）。
  flake.nixosModules.nixbot-metrics =
    { config, lib, ... }:
    let
      # nixbot 只监听回环（services.nixbot.port，见 modules/services/nixbot.nix）。
      # 本模块目前只在 home-server（selfhost → monitoring）上导入，那里一定有
      # nixbot 选项；用 attrByPath 只是让没导入 nixbot 的机器求值不炸。
      nixbotPort = lib.attrByPath [ "services" "nixbot" "port" ] 8010 config;
    in
    {
      services.victoriametrics.prometheusConfig.scrape_configs = [
        {
          job_name = "nixbot";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString nixbotPort}" ];
              # 和 telegraf 的约定一致（host = 机器名）。alertmanager-ntfy 的标题
              # 模板会先取 site、再取 host、最后 falls back 到 instance，
              # 不设这个标签时通知标题里的括号就是 127.0.0.1:8010。
              labels.host = config.networking.hostName;
            }
          ];
        }
      ];

      services.vmalert.instances.metrics.rules.groups = [
        {
          name = "nixbot";
          rules = [
            {
              alert = "NixbotMetricsMissing";
              # 端点没了 = nixbot 挂了 / 抓取坏了。所有下面的规则都会跟着静音，
              # 所以这一条必须单独报。用 nixbot_queue_depth 而不是 nixbot_builds：
              # 后者只对存在过的状态出序列，空库/刚清过库时本来就没有。
              expr = "absent_over_time(nixbot_queue_depth[15m])";
              for = "10m";
              labels.severity = "critical";
              annotations.summary = "nixbot 指标抓不到了";
              annotations.description = "VictoriaMetrics 20 分钟没抓到 nixbot 的 /metrics（窗口 15m + for 10m），先看 systemctl status nixbot；nixbot 挂掉期间所有下面这些 nixbot 告警都是哑的。";
            }
            {
              alert = "NixbotPushEffectFailed";
              # owner="build" = onPush 的 effect（部署/发布/推送镜像这类）加上每个
              # build 的 effect check。effect 本身默认不在 PR 上跑（PR 上的行是
              # status=skipped，不匹配这里），但 effect **定义/依赖**坏了会让 PR 的
              # effect check 变成 failed，所以这条在 PR 上偶尔也会响。
              expr = ''delta(nixbot_effects{owner="build",status=~"failed|dependency_failed"}[1h]) > 0'';
              for = "10m";
              labels.severity = "critical";
              annotations.summary = "nixbot 的 onPush effect 失败";
              annotations.description = "最近一小时有 onPush effect 失败（含依赖失败）：默认分支上的部署/发布这类动作没做成，或者某个 PR 把 effect 的依赖改坏了（effect check 也算在这条里）。去 https://nixbot.lubui.com:8443/ 的 Effects 页面按仓库找失败的 effect 看日志。";
            }
            {
              alert = "NixbotScheduledTaskFailed";
              # onSchedule 的 effect，不限仓库。
              expr = ''delta(nixbot_effects{owner="schedule",status=~"failed|dependency_failed"}[1h]) > 0'';
              for = "10m";
              labels.severity = "critical";
              annotations.summary = "nixbot 定时任务失败";
              annotations.description = "最近一小时有 onSchedule 的 effect 失败（含依赖失败）。具体是哪个仓库、哪条 schedule，去 https://nixbot.lubui.com:8443/ 的 Schedules 表格看，点进去有日志。";
            }
            {
              alert = "NixbotSchedulerStalled";
              # lag 是所有仓库所有 schedule 里「最近一次触发」距今的时间，
              # 所以阈值要按最频繁的那种定时任务设。
              expr = "nixbot_scheduled_effect_lag_seconds > 2*86400";
              for = "10m";
              labels.severity = "warning";
              annotations.summary = "nixbot 两天没触发过任何定时任务";
              annotations.description = "nixbot_scheduled_effect_lag_seconds = {{$value}} 秒：nixbot 管的所有 schedule 里，最近一次触发已经是两天前。调度线程挂了、或者 schedule 解析不出来时是这样；如果仓库里只有周期性很稀的任务（比如周级），把阈值调大。";
            }
            {
              alert = "NixbotBuildFailed";
              # 最粗的一层：所有构建失败都算，**包括 PR 上的**。PR 上正在推的
              # WIP 提交本来就会红，觉得吵就把这条删掉、只留上面两条 effect 告警。
              expr = ''delta(nixbot_builds{status="failed"}[1h]) > 0'';
              for = "10m";
              labels.severity = "warning";
              annotations.summary = "nixbot 有构建失败";
              annotations.description = "最近一小时有新失败的构建（包含 PR 构建，可能只是 WIP 提交）。默认分支的构建失败时它的 onPush effect 根本不会跑、也就不会有上面那条 effect 告警，所以这条别删太快。";
            }
            {
              alert = "NixbotEffectStuck";
              # effect 卡住（网络 hang、等锁、bwrap 里进程没退）比失败更难发现：
              # 它一直 running，既不算失败也不会推进部署。
              expr = "nixbot_effects_oldest_running_age_seconds > 4*3600";
              for = "15m";
              labels.severity = "warning";
              annotations.summary = "nixbot 有 effect 卡在 running";
              annotations.description = "{{$labels.owner}} 的 effect 已经连续跑了 {{$value}} 秒（> 4 小时），远长于一次部署/定时任务。可能是 ssh 卡住或目标机不响应，去 nixbot 上 systemctl status nixbot 并看该 effect 的日志流。";
            }
            {
              alert = "NixbotWorkQueueStuck";
              # pending 的队列项自己不会超时：调度线程卡死时队列只会越来越长，
              # 界面上看起来“还在排队”。
              expr = ''max by (kind) (nixbot_work_queue_oldest_age_seconds{status="pending"}) > 2*3600'';
              for = "15m";
              labels.severity = "warning";
              annotations.summary = "nixbot 的 {{$labels.kind}} 工作队列堵住";
              annotations.description = "最老的 pending {{$labels.kind}} 队列项已经等了 {{$value}} 秒（> 2 小时）。队列自己不会超时，检查 nixbot 日志里的 dispatcher 是否还在推进。";
            }
            {
              alert = "NixbotUploadsRetrying";
              # 二进制缓存推送失败是典型的“静默失败”：构建和部署都成功，
              # 只是缓存没上去，下次别的机器构建还要自己编。
              expr = "nixbot_upload_queue_retrying > 0";
              for = "30m";
              labels.severity = "warning";
              annotations.summary = "nixbot 往二进制缓存推送一直在失败";
              annotations.description = "{{$labels.uploader}} 有 {{$value}} 个路径推送失败后还在重试（持续 30 分钟）。检查缓存服务的可达性、以及推送用的凭据/签名配置。";
            }
          ];
        }
      ];
    };
}
