# 给 dae 提供「本地 DNS 记录」的小 dnsmasq。
#
# 为什么需要它：dae 的 dns 只能把查询按 qname 路由到某个上游，没有
# sing-box 里 `action = "predefined"` 那种直接回答静态 A 记录的能力。
# 所以原来写在 `modules/services/sing-box/_home.nix` dns.rules 里的
# `.lan` / `*.lubui.com` 记录搬到这里。
#
# 只监听 127.0.0.1:15353，不碰 53：dae 在内核里直接应答 53 的查询，
# 自己再通过 `udp://127.0.0.1:15353` 这个上游来查本地记录。
# 53 端口不需要任何进程监听。
#
# 注意：`.lan` 里没有列出的名字以前会落到公共 DNS 拿 NXDOMAIN；dnsmasq 在
# 没有上游时默认回 REFUSED，而 REFUSED 经过 systemd-resolved 会让客户端
# 卡到超时（dig 表现为 timed out）。所以最后加一条空的 `address=/lan/`，
# 让未列出的名字直接 NXDOMAIN（空地址 = NXDOMAIN，dnsmasq 会优先匹配
# 更具体的那条，所以上面列出的 host 不受影响）。
# 想加新名字往下面的 address 里加一行即可。
{
  flake.nixosModules.dnsmasq-local =
    { ... }:
    {
      services.dnsmasq = {
        enable = true;

        # 不要接管 /etc/resolv.conf（dae 已经在内核层劫持 53）
        resolveLocalQueries = false;

        settings = {
          port = 15353;
          listen-address = "127.0.0.1";
          bind-interfaces = true;

          # 纯本地记录：没有上游、不读 /etc/hosts、不缓存
          # （缓存交给 dae，避免两份 TTL 互相打架）
          no-resolv = true;
          no-hosts = true;
          cache-size = 0;

          address = [
            # 对应原 sing-box 的 domain_suffix ".lubui.com" → 192.168.1.7。
            # www / huyue / any / any.home 这几个公网名字在 dae 的 dns
            # 路由里先被送去 alidns，不会查到这里。
            "/lubui.com/192.168.1.7"

            # 原 sing-box dns.rules 里的 localHosts
            "/home-server.lan/192.168.2.1"
            "/macmini.lan/192.168.2.2"
            "/router.lan/192.168.2.3"
            "/nixos-desktop.lan/192.168.2.5"
            "/termux.lan/192.168.2.6"
            "/rpi.lan/192.168.2.7"
            "/kindle.lan/192.168.2.9"
            "/orangepi5plus.lan/192.168.2.11"
            "/ali-cloud-light-vmess.lan/47.76.155.157"

            # 兑底：其他 .lan 直接 NXDOMAIN（见文件头的说明）
            "/lan/"
          ];
        };
      };
    };
}
