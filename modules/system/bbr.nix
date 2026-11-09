# 跨境链路 / 代理服务器的 TCP 调优：BBR + fq + 缓冲与连接数上限。
# 只在「单机跑代理」这类机器上开（目前是 tencent-cloud-korea），普通主机不需要。
{
  flake.nixosModules.bbr =
    { pkgs, ... }:
    {
      boot.kernelModules = [
        "tcp_bbr"
        # CONFIG_NET_SCH_FQ=m，不加载 sch_fq 的话 net.core.default_qdisc=fq 只是摆设。
        "sch_fq"
        # net.netfilter.* sysctl 依赖它；防火墙（加载 conntrack 的地方）比 systemd-sysctl 起得晚，
        # 不显式加载的话这两项 sysctl 会在开机时报 "No such file or directory"。
        "nf_conntrack"
      ];

      boot.kernel.sysctl = {
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.default_qdisc" = "fq"; # BBR 的官方推荐搭配

        # ---- 单流吞吐：跨境 RTT 大，窗口上限直接决定单连接能跑多快 ----
        "net.ipv4.tcp_rmem" = "4096 87380 16777216";
        "net.ipv4.tcp_wmem" = "4096 65536 16777216";
        # 只对显式设置 SO_RCVBUF/SO_SNDBUF 的程序有意义（自动调优看 tcp_rmem/tcp_wmem）
        "net.core.rmem_max" = 16777216;
        "net.core.wmem_max" = 16777216;

        # ---- 延迟与健壮性 ----
        # 长连接空闲后不要回到慢启动（mux 场景很关键）
        "net.ipv4.tcp_slow_start_after_idle" = 0;
        # Cloudflare 推荐值：压小发送队列积压，改善交互延迟
        "net.ipv4.tcp_notsent_lowat" = 16384;
        # 跨境隧道路径有 MTU 黑洞时自动探测，否则大包会一直卡住
        "net.ipv4.tcp_mtu_probing" = 1;
        "net.ipv4.tcp_fastopen" = 3;

        # ---- 连接数与端口 ----
        "net.core.somaxconn" = 4096;
        "net.ipv4.tcp_max_syn_backlog" = 8192;
        "net.core.netdev_max_backlog" = 16384;
        "net.ipv4.tcp_tw_reuse" = 1;
        "net.ipv4.ip_local_port_range" = "10240 65535";

        # ---- conntrack：每条代理连接都会占一项（4G 内存给 26 万足够）----
        "net.netfilter.nf_conntrack_max" = 262144;
        "net.netfilter.nf_conntrack_tcp_timeout_established" = 1200;
      };

      # net.core.default_qdisc 只在「网卡注册时」决定默认 qdisc，而云主机的 virtio 网卡在内核
      # 启动阶段就注册好了（远早于 systemd-sysctl），所以开机后 eth0 上仍然是 fq_codel。
      # 实测：写 sysctl 后 sch_fq 会被加载，但已存在的网卡 qdisc 不会变。
      # 这里在开机后显式换掉物理网卡的 qdisc，否则 fq 永远是摆设。
      #
      # 注意：virtio 双队列网卡的 root 是 mq，内核隐式创建时 handle 是 0，此时既不能
      # `replace root`（会把 mq 整个替换掉），也不能按队列 `parent 0:1` 换子 qdisc（tc 报
      # "Failed to find specified qdisc"）。权衡下来直接用 `replace root fq`：会丢掉多队列，
      # 但 fq 单队列在带宽受限的 VPS 上完全够用，而 mq 只在几 Gbps 以上才体现差异。
      systemd.services.set-fq-qdisc = {
        description = "Set fq qdisc on physical NICs (for BBR)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = with pkgs; [
          iproute2
          gnugrep
          coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          for dir in /sys/class/net/*; do
            dev=$(basename "$dir")
            # 只看物理网卡，跳过 lo / tun / veth 之类
            [ -e "$dir/device" ] || continue
            # 已经是 fq 就跳过
            tc qdisc show dev "$dev" | head -n 1 | grep -q ' fq ' && continue

            tc qdisc replace dev "$dev" root fq || true
          done
        '';
      };
    };
}
