{
  flake.nixosModules.telegraf =
    { pkgs, ... }:
    {
      # telegraf 以 telegraf 用户跑，而 smartctl 需要 CAP_SYS_RAWIO / CAP_DAC_OVERRIDE
      # 才能直接读 /dev/sda、/dev/nvme0 的 SMART 数据。只给这个二进制单独提权，
      # 不给整个 telegraf 服务加 CAP_SYS_ADMIN（做法和 srvos 的 telegraf mixin 一致）。
      security.wrappers.smartctl-telegraf = {
        owner = "telegraf";
        group = "telegraf";
        capabilities = "cap_sys_admin,cap_dac_override,cap_sys_rawio+ep";
        source = "${pkgs.smartmontools}/bin/smartctl";
      };

      services.telegraf = {
        enable = true;

        extraConfig = {
          agent = {
            interval = "60s";
            flush_interval = "60s";
          };

          inputs = {
            # 常用的查询（VictoriaMetrics UI 或 Grafana 里）：
            #   x509_cert_expiry{type="leaf",site="lubui.com"} / 86400   # 证书剩余天数
            #   (whois_expiration_timestamp{domain="lubui.com"} - time()) / 86400  # 域名注册剩余天数
            #   http_response_result_code{site="lubui.com"}              # 0 = 请求成功
            #   http_response_response_time{site="lubui.com"}            # 响应耗时（秒）
            #   systemd_units_active_code != 0                           # 非 active 的 systemd 单元
            #   disk_used_percent >= 80                                  # 快满的文件系统
            #   smart_device_health_ok != 1                              # SMART 总体健康位失败
            #   smart_attribute_raw_value{id="197"} > 0                  # 待定坏扇区，任何非 0 都该看
            #
            # 注意 interval **不要**写成小时级：telegraf 不会在启动时先采一次，
            # 第一个采样点要等满一个 interval 才出现（实测 6h 的插件启动 8s 后指标数是 0）。
            # 而且 prometheus_client 只把指标缓存在内存里，telegraf 一重启，
            # 稀疏指标就从 /metrics 里消失，直到下次采集 —— 看板上就是一个大洞。
            # 所以面向本机的采集一律用分钟级，想降采样放到 VictoriaMetrics 那边做。
            #
            # 唯一的例外是下面的 whois：它查的是外部 WHOIS 服务器（有限流），
            # 分钟级就是一天上千次查询。那里用 6h，并且靠 vmalert 的
            # WhoisMetricMissing（24h 窗口）兜住「重启后没数据」这段空窗。

            # 网站可用性：状态码 200 且请求能完成才算 result_code == 0
            #
            # 一个 [[inputs.http_response]] = 一个探针实例，tags.site 就是 Grafana 里
            # 站点面板的分组维度（看板用 label_values(http_response_result_code, site)
            # 自动发现站点，加网站只要在这里加一段）。
            # 不要把一个实例的 urls 写成多个站点：那样所有站点共用同一个 site tag，
            # 只剩 server tag 能区分，max by (site) 会把它们压成一条。
            #
            # 站点维度刻意用 site 而不是 host：telegraf 默认会把 host 设成主机名，
            # 复用 host 会让同一 label 里混进两种语义（站点名和机器名）。
            http_response = [
              {
                urls = [ "https://lubui.com/" ];
                response_status_code = 200;
                response_timeout = "10s";
                interval = "60s";
                tags.site = "lubui.com";
              }
              {
                urls = [ "https://home.lubui.com:8443" ];
                response_status_code = 200;
                response_timeout = "10s";
                interval = "60s";
                tags.site = "home.lubui.com";
              }
            ];

            # TLS 证书剩余有效期，单位秒。
            # 证书一天才变一次，10 分钟足够；但不能写成小时级：
            #   - telegraf 不在启动时先采一次，重启后要等满一个 interval 才有第一个点
            #   - vmalert 的 CertProbeMissing 是 absent(...) 超过 15 分钟就报
            # 之前在 1h 下，每次 telegraf 重启都必然误报一个 CertProbeMissing（实测）。
            x509_cert = [
              {
                sources = [ "https://lubui.com:443" ];
                timeout = "10s";
                interval = "10m";
                tags.site = "lubui.com";
              }
              {
                sources = [ "https://home.lubui.com:8443" ];
                timeout = "10s";
                interval = "10m";
                tags.site = "home.lubui.com";
              }
            ];

            # 域名注册到期（WHOIS，默认先问 whois.iana.org 拿到 TLD 的权威 server，
            # .com 实际查的是 whois.verisign-grs.com；注册信息里的到期日是权威的）。
            # 指标（string 字段会变成 label，所以带 registrar/status 等）：
            #   whois_expiration_timestamp{domain=...}  # 绝对到期时间（unix 秒），0 = 没查到
            #   whois_expiry{domain=...}               # 采样当时还剩多少秒
            # 告警规则只用绝对时间戳，因为 expiry 会被采样间隔（6h）带偏。
            #
            # interval 必须显式写：不写就继承 agent 的 60s，一天 1440 次 WHOIS 查询，
            # 既浪费又容易被注册商限流。到期日一年才变一次，6h 完全够。
            # 代价是 telegraf 重启后最多 6h 才出现第一个采样点（见上面注意事项），
            # 所以 vmalert 里“采集缺失”那条用的是 24h 窗口而不是 15m。
            whois = [
              {
                domains = [ "lubui.com" ];
                interval = "6h";
                timeout = "30s";
              }
            ];

            # 系统级 systemd 单元状态：
            #   systemd_units_active_code{name="jellyfin.service"}   # 0=active 2=inactive 3=failed
            #   systemd_units_restarts{name="jellyfin.service"}      # 重启次数（details 模式才有）
            # 走 system bus，telegraf 以 telegraf 用户读只读属性即可，不需要额外权限。
            # 一个 [[inputs.systemd_units]] 只能采一种 unittype，所以这里写三条；
            # 想加 socket/swap 之类照抄一条改 unittype 即可。
            systemd_units = [
              {
                unittype = "service";
                # details 模式下额外给出 restarts/pid/mem 等字段，
                # 崩溃重启循环的告警（vmalert 里的 SystemdServiceRestartLoop）依赖它
                details = true;
              }
              {
                unittype = "timer";
              }
              {
                # 挂载单元：外挂盘（/mnt/hdd、/mnt/btr_backup）是 nofail 挂的，
                # 盘不在线时 systemd 只是把 unit 标成 failed/inactive，不会阻塞启动，
                # 而 disk 输入直接看不到那个挂载点 —— 不采 mount unit 就完全静默。
                unittype = "mount";
              }
            ];

            # --- 下面几条是给 srvos 默认规则提供数据源的，删掉对应的规则就哑了 ---

            # Load15 / Uptime / Reboot（system_load15、system_uptime）
            system = { };

            # RamUsing95Percent / SwapUsing30Percent（mem_*、mem_swap_*）
            # 注意本机开了 zram，swap 里含 zram：内存一紧张 swap 用量就会上去，
            # 30% 的阈值可能偏敏感，觉得吵就把 srvos 那条的系数改大。
            mem = { };

            # OomKills / HostMemoryUnderMemoryPressure（kernel_vmstat_oom_kill、pgmajfault）
            kernel_vmstat = { };

            # Filesystem80percentFull / FilesystemInodesFull / Ext4Errors（disk_used_percent 等）
            # telegraf 1.40 的 disk 默认不过滤 tmpfs/devtmpfs，不排掉的话
            # 每个 /run/user/* 都会冒出一条序列，还会把“/run 满了”这种噪音算进来。
            # podman 的 overlay 挂载同理，必须排除，否则容器一多序列数会爆。
            disk = {
              ignore_fs = [
                "tmpfs"
                "devtmpfs"
                "devfs"
                "overlay"
                "squashfs"
                "ramfs"
                "autofs"
                "proc"
                "procfs"
                "sysfs"
                "cgroup"
                "cgroup2"
                "nsfs"
                "pstore"
                "fuse"
                "fusectl"
                "mqueue"
                "debugfs"
                "tracefs"
                "securityfs"
                "efivarfs"
                "binfmt_misc"
                "configfs"
                "bpf"
                "hugetlbfs"
                "rpc_pipefs"
              ];
            };

            # UnusualDiskReadLatency / UnusualDiskWriteLatency（diskio_read_time 等）
            # devices 支持 glob；不写就是所有设备（含 loop），这里只要真实盘。
            diskio = {
              devices = [
                "sd*"
                "nvme*"
              ];
            };

            # SmartErrors（smart_device_health_ok != 1）
            # attributes = true 才有 smart_attribute_raw_value，
            # “磁盘在恶化”（重映射/待定/不可纠正扇区 > 0）的告警依赖它。
            # nocheck 默认 standby：不会为了采样把机械盘唤醒。
            smart = {
              path_smartctl = "/run/wrappers/bin/smartctl-telegraf";
              attributes = true;
            };

            # telegraf 自身的采集/写入健康度，便于排查探针不工作时是探测失败还是 agent 卡住
            internal = { };
          };

          # 只监听本机，由同机的 VictoriaMetrics 来拉；不对外暴露
          outputs.prometheus_client = {
            listen = "127.0.0.1:9273";
            metric_version = 2;
          };
        };
      };
    };
}
