# 客户端共用的 outbounds。
#
# home-server 自己的 sing-box 和 Android 订阅都用这一份：新增协议时只改这里，
# 两边的 selector 都会自动带上，避免两份配置漂移。
#
# `default` 是 selector 的默认节点：home-server 用 vless-kr-reality，手机用 hysteria2-kr。
{
  sing-box-hk,
  sing-box-kr,
  sing-box-kr-reality,
  sing-box-kr-hysteria2,
  default ? "vmess-kr",
}:
let
  mkVMessOutput = name: vars: {
    tag = name;
    alter_id = 0;
    authenticated_length = true;
    global_padding = false;
    multiplex = {
      enabled = true;
      max_connections = 4;
    };
    security = "auto";
    server = vars.remote_ip.value;
    server_port = 8443;
    tls = {
      certificate = [ vars.crt.value ];
      disable_sni = false;
      enabled = true;
      insecure = false;
      server_name = vars.remote_domain.value;
    };
    transport = {
      headers = {
        Host = vars.remote_domain.value;
      };
      path = "/Dacexo5f/";
      type = "ws";
    };
    type = "vmess";
    uuid._secret = vars.uuid.path;
  };

  # KR 的 REALITY 节点（VLESS + Vision）：没有证书要 pin，也不用 CDN。
  # 注意 server_name 必须是握手目标站点，不是 kr.lubui.buzz。
  vless-kr-reality = {
    tag = "vless-kr-reality";
    type = "vless";
    server = sing-box-kr.remote_ip.value;
    server_port = 443;
    uuid._secret = sing-box-kr.uuid.path;
    flow = "xtls-rprx-vision";
    tls = {
      enabled = true;
      server_name = sing-box-kr-reality.handshake_domain.value;
      utls = {
        enabled = true;
        fingerprint = "chrome";
      };
      reality = {
        enabled = true;
        public_key = sing-box-kr-reality.public_key.value;
        short_id = sing-box-kr-reality.short_id.value;
      };
    };
  };

  # KR 的 hysteria2 节点（QUIC/UDP 443，obfs salamander）。
  # UDP 通畅时比 TCP 方案快；UDP 被封时切回 vless-kr-reality 或 vmess。
  hysteria2-kr = {
    tag = "hysteria2-kr";
    type = "hysteria2";
    server = sing-box-kr.remote_ip.value;
    server_port = 443;
    password._secret = sing-box-kr-hysteria2.password.path;
    obfs = {
      type = "salamander";
      password._secret = sing-box-kr-hysteria2.obfs_password.path;
    };
    tls = {
      enabled = true;
      certificate = [ sing-box-kr.crt.value ];
      insecure = false;
      server_name = sing-box-kr.remote_domain.value;
    };
  };
in
[
  {
    tag = "direct-out";
    type = "direct";
  }
  {
    tag = "proxy-out";
    type = "selector";
    inherit default;
    outbounds = [
      "vmess-hk"
      "vmess-kr"
      "vless-kr-reality"
      "hysteria2-kr"
      "direct-out"
    ];
  }

  (mkVMessOutput "vmess-hk" sing-box-hk)
  (mkVMessOutput "vmess-kr" sing-box-kr)
  vless-kr-reality
  hysteria2-kr
]
