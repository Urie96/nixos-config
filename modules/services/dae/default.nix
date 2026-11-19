# dae：Linux 内核 eBPF(tc) 透明代理客户端。它接替 home-server 原来那套
# sing-box TUN 网关（`modules/services/sing-box/_home.nix`，已停用）。
#
# 配置直接作为 sops template，`configFile` 指向它渲染出来的文件：
#
#   sops.templates."dae-config"  →  /run/secrets/rendered/dae-config
#                                          ↓ services.dae.configFile（LoadCredential）
#                                         dae
#
# 关于 secret 的一个坑：clan var 的值是生成脚本写出来的，如果脚本用
# `print()` / `echo`，值结尾会多一个 `\n`；而 sops 的占位符替换是**纯字符串
# 替换**，不裁剪空白。换行被塞进 node 链接中间时 dae 会报
#
#   failed to parse node: ... net/url: invalid control character in URL
#
# 并把节点丢掉、`proxy` 组变空（`dae validate` 不报错，服务照常启动，
# 但境外流量和境外 DNS 全挂）。所以 sing-box 的 uuid generator 已经改成
# 用 `sys.stdout.write` 写值，存量的 uuid 也去掉了结尾换行。以后新加的
# generator 要往 dae 配置里插值时，别用 `print` / `echo` 写文件。
{
  flake.nixosModules.dae-home =
    { config, pkgs, ... }:
    let
      vars = config.clan.core.vars.generators;
      # 服务端地址 / REALITY 参数都不是 secret，eval 期就能取到 .value。
      kr = vars.sing-box-kr.files;
      reality = vars.sing-box-kr-reality.files;

      # 网卡和地址与 modules/system/router.nix 保持一致，改那边记得同步。
      wanInterface = "enp199s0f4u1u2";
      lanInterface = "enp2s0";
      lanIp = "192.168.2.1";

      # ---------------------------------------------------------------
      # 节点
      # ---------------------------------------------------------------
      # 目前只挂了 KR 的 VLESS+REALITY。另外两个节点暂时接不进来：
      #
      #   * hysteria2-kr：服务端开了 obfs salamander，而 dae 的 hysteria2
      #     出站不支持 obfs（outbound 里还是 TODO）。要在 dae 上用，
      #     得在服务端 `_make-hysteria2.nix` 里去掉 obfs（sing-box 客户端
      #     那边也要同步删 obfs 段），并把 hysteria2 密码的 generator
      #     也改成不带尾换行（现在那两个密码还是 `openssl rand -hex` 写的）。
      #   * vmess-hk / vmess-kr：vmess 分享链接是 base64(JSON)，uuid 藏在
      #     base64 内部，没法把占位符塞进去。要恢复可以给这些 VPS 也加
      #     REALITY（纯服务端小改，推荐）。
      nodeLink = "vless://${config.sops.placeholder."vars/shared/sing-box-kr/uuid"}@${kr.remote_ip.value}:443"
        + "?encryption=none&flow=xtls-rprx-vision&security=reality"
        + "&sni=${reality.handshake_domain.value}&fp=chrome"
        + "&pbk=${reality.public_key.value}&sid=${reality.short_id.value}"
        + "&type=tcp#vless-kr-reality";

      daeConfig = ''
        global {
            # 只给 eBPF 用的 tproxy 端口，不是 socks/http 代理端口。
            tproxy_port: 12345
            tproxy_port_protect: true

            # WAN 绑上才能劫持本机进程的流量，LAN 绑上才能代理整个
            # 192.168.2.0/24（DHCP 在 modules/services/kea.nix 里把网关
            # 指向这台机器）。
            wan_interface: ${wanInterface}
            lan_interface: ${lanInterface}

            # ip_forward / send_redirects / rp_filter 由 dae 自己配。
            auto_config_kernel_parameter: true

            # 想排查分流为什么不对时改成 info（会有每连接的日志）。
            log_level: warn

            # domain：用 sniff 到的域名去拨号，代理端重新解析，
            # 等价于原来 sing-box 的 sniff + 代理端解析。
            # 改成 ip 会关闭 sniff，域名分流也就失效了。
            dial_mode: domain
            sniffing_timeout: 30ms

            # 原 REALITY 节点用 uTLS 模仿 chrome（fingerprint = chrome），
            # 这里设成全局默认，新加节点不用重复写。
            tls_implementation: utls
            utls_imitate: chrome_auto

            tcp_check_url: 'http://cp.cloudflare.com,1.1.1.1'
            udp_check_dns: '8.8.8.8:53'
            check_interval: 30s
            check_tolerance: 50ms
        }

        node {
            vless-kr-reality: '${nodeLink}'
        }

        group {
            proxy {
                filter: name(vless-kr-reality)
                # 只有一个节点时固定选它。补上节点后改成
                #   policy: min_moving_avg
                # 让 dae 按 tcp/udp 探活自动挑最快的那个。
                policy: fixed(0)
            }
        }

        dns {
            # 对应原 sing-box 的 dns.strategy: ipv4_only，但**不等价**，别指望它
            # 兜住 IPv6：dae 只在“已经知道这个域名有 A 记录”时才把 AAAA 应答换成
            # 空的 NOERROR —— 条件是缓存里有未过期的 A，或者 AAAA 查询等待 50ms
            # 内收到了带记录的 A。这里的境外 DNS 走 tls://8.8.8.8:853 过代理，
            # RTT 上百毫秒，50ms 窗口根本等不到 A，AAAA 照旧原样返回（实测
            # dig AAAA whois.iana.org 仍有记录），本地进程还是会优先用 IPv6。
            # IPv6 的问题在下面 routing 的 dip('::/0') 规则里处理。
            ipversion_prefer: 4

            upstream {
                # 国内域名 / 国内 DNS
                alidns: 'udp://223.5.5.5:53'
                # 境外域名：由下面 routing 的 fallback 送到 proxy 组，
                # 等价于原 sing-box 的 detour: proxy-out。
                # 8.8.8.8 的证书带 IP SAN，Go 的 TLS 能直接校验；
                # 万一不通可以换成 'https://dns.google/dns-query'。
                dns-proxy: 'tls://8.8.8.8:853'
                # 本地记录，见 modules/services/dnsmasq.nix
                localdns: 'udp://127.0.0.1:15353'
            }

            routing {
                request {
                    # lubui.com 自己是腾讯云 CDN 上的站点（CNAME →
                    # lubui.com.cdn.dnsv1.com），这几个公网名字必须真实解析。
                    # 它们必须排在下面的 suffix 规则前面：dae 的
                    # qname(suffix: lubui.com) 连 apex 本身也会匹配，
                    # 不先拦住的话 lubui.com 会被 dnsmasq 答成 192.168.1.7。
                    qname(full: lubui.com) -> alidns
                    qname(full: www.lubui.com) -> alidns
                    qname(full: huyue.lubui.com) -> alidns
                    qname(full: any.lubui.com) -> alidns
                    qname(full: any.home.lubui.com) -> alidns

                    # 其余 *.lubui.com 和 *.lan 的 A 记录由 dnsmasq 回答
                    qname(suffix: lubui.com) -> localdns
                    qname(suffix: lan) -> localdns

                    # 原 sing-box：geosite-category-ads-all → reject
                    qname(geosite:category-ads-all) -> reject

                    qname(geosite:cn) -> alidns
                    fallback: dns-proxy
                }
            }
        }

        routing {
            # dae 自己回查本地 dnsmasq：必须直连且不劫持，否则会绕回
            # 自己的 DNS 模块造成环路。
            dip(127.0.0.1) -> must_direct

            # ddns 取到的必须是本机公网 IP，不能被代理。
            # （原来是 process_name = ddns-updater，实际跑的是 ddns-go。）
            pname(ddns-go) -> must_direct
            pname(ddns-updater) -> must_direct

            # 广播 / 组播不要进用户态
            dip(224.0.0.0/3, 'ff00::/8') -> direct

            # LAN 设备访问 home-server 自己的服务（immich/jellyfin/gitea…）时
            # 不要让 dae 劫到用户态再连回来。必须排在 dip(geoip:private)
            # 前面，否则会被那条更宽的 direct 规则先匹配掉。
            dip(${lanIp}) -> must_direct

            # 内网（192.168.2.0/24、127.0.0.0/8、podman 网段…）直连
            dip(geoip:private) -> direct

            # WAN 上 18443 → KR:8443 的 DNAT（见 modules/system/router.nix），
            # 这条转发不能再被 dae 劫走。
            dip(${kr.remote_ip.value}) && dport(8443) -> must_direct

            # 原 sing-box 的 geosite-direct-extra
            domain(full: addons.mozilla.org) -> direct
            domain(full: ddns.oray.com) -> direct
            domain(full: ip.3322.net) -> direct

            # 国内直连（顺序与原来一致：先按 IP，再按域名）
            dip(geoip:cn) -> direct
            domain(geosite:cn) -> direct
            domain(geosite:steam@cn) -> direct

            # 出口没有 IPv6：KR 节点上 `ip -6 addr` 没有全局地址、`ip -6 route`
            # 只有 fe80::/64，所以任何被 fallback 到 proxy 的 IPv6 目标都连不上。
            # 这种失败在本机看起来是“连上了但没有数据”：dae 先把 TCP 握手
            # 应答了，等上游失败再 FIN，客户端收到 0 字节且没有 RST —— 也就
            # 不会触发 Happy Eyeballs 回落 IPv4。2026-11-15 切到 dae 之后
            # telegraf 的 whois 输入就是这么挂的：它查 whois.iana.org，Go 拨号
            # 优先取 AAAA，拿到空响应后 whoisparser 报
            # “domain whois data is invalid”，whois_expiration_timestamp 连续
            # 24h 无样本 → WhoisMetricMissing 告警（v4 一直是好的）。
            # 这里让所有 IPv6 目标直连：国内 v6 本来就被 dip(geoip:cn) 拦成
            # direct，境外 v6 走代理时 100% 是死的，直连至少能用。注意在
            # dip(geoip:private) / 组播规则之后，它们已经先匹配掉了。
            # 以后给 KR 节点配上 IPv6 出口，要删掉或收紧这条规则，否则 IPv6
            # 流量会绕过代理。
            #
            # 必须用 ipversion(6)，不要写成 dip('::/0')：dae 的 LPM trie 键
            # 一律是 128 位的（control/kern/tproxy.c 里 route() 直接 memcpy
            # IPV6_BYTE_LENGTH 字节，prefixlen 初始 128），一个 0 位前缀
            # 会命中**所有**目标，IPv4 也算在内。2026-11-18 的 commit 里用的
            # 就是 dip('::/0')，第二天 04:34 部署后 dae 把全部流量（本机 +
            # LAN）都判成 direct，境外站点和 Telegram 直连全挂（tgdl 因此卡在
            # SYN-SENT）。
            ipversion(6) -> direct

            fallback: proxy
        }
      '';
    in
    {
      # -----------------------------------------------------------------
      # 整份 dae 配置就是一个 sops template（store 里只有占位符哈希）
      # -----------------------------------------------------------------
      sops.templates."dae-config" = {
        content = daeConfig;
        # secret 变了就让 dae 重启（重新渲染 = 重启）
        restartUnits = [ "dae.service" ];
      };

      services.dae = {
        enable = true;
        configFile = config.sops.templates."dae-config".path;
      };

      systemd.services.dae = {
        wants = [ "dnsmasq.service" ];
        # dae 的 DNS 会把 .lan / *.lubui.com 的查询转给 127.0.0.1:15353 上的
        # dnsmasq（modules/services/dnsmasq.nix），启动顺序上让它先起来。
        after = [ "dnsmasq.service" ];
      };

      assertions = map (secret: {
        assertion = builtins.hasAttr secret config.sops.secrets;
        message = ''
          dae 需要 sops secret `${secret}`，但它不存在。

          检查 modules/services/sing-box/default.nix 里 `sing-box-kr` 这个
          generator 是否还在（uuid 就是从这里来的），以及 clan 的
          secretStore 是否为 sops。
        '';
      }) [ "vars/shared/sing-box-kr/uuid" ];
    };
}
