# REALITY 服务端 inbound（VLESS + Vision）。
#
# 和 _make-singbox-oversea.nix 的区别：REALITY 不用证书、不用域名、也不需要另起
# nginx 或静态网页。服务端只持有一对 X25519 密钥和一个 short_id，TLS 握手阶段
# "借用" handshake.server 这个真实站点的证书；没带认证信息的连接（扫描器、
# 主动探测）会被原样转给那个真实站点，看到的是人家的真证书真页面。
#
# 参数：
#   name          —— clan vars generator 的名字（提供 private_key / public_key /
#                    short_id / handshake_domain）
#   uuidGenerator —— 复用哪个 generator 的 uuid（和同机的 vmess 共用一个即可）
{ name, uuidGenerator }:
{ config, ... }:
let
  vars = config.clan.core.vars.generators.${name}.files;
  uuid = config.clan.core.vars.generators.${uuidGenerator}.files.uuid;
in
{
  services.sing-box.settings = {
    inbounds = [
      {
        type = "vless";
        tag = "reality-in";
        listen = "::";
        listen_port = 443;
        users = [
          {
            name = "urie";
            uuid._secret = uuid.path;
            flow = "xtls-rprx-vision";
          }
        ];
        tls = {
          enabled = true;
          # 客户端 SNI 必须等于这个值，否则握手会被当成探测流量转给真实站点
          server_name = vars.handshake_domain.value;
          reality = {
            enabled = true;
            handshake = {
              server = vars.handshake_domain.value;
              server_port = 443;
            };
            private_key._secret = vars.private_key.path;
            short_id = [ vars.short_id.value ];
          };
        };
      }
    ];

    route.rules = [
      {
        inbound = "reality-in";
        action = "route";
        outbound = "direct";
      }
    ];
  };
}
