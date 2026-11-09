# Hysteria2 服务端 inbound（QUIC/UDP）。
#
# 和 REALITY 互补：REALITY 走 TCP 443，hysteria2 走 UDP 443，同一个端口号互不冲突。
# UDP 通畅的网络里，跨境丢包场景比 TCP 方案快不少；UDP 被封时还能切回 REALITY/vmess。
#
# TLS 复用 sing-box-<site> generator 里那张自签证书（SAN 里有 KR 的域名和 IP），
# 客户端要把同一张 cert 钉进去（或者设 insecure，但这台不推荐）。
#
# 参数：
#   name    —— clan vars generator 的名字（提供 password / obfs_password）
#   certFrom —— 复用哪个 generator 的 crt / key / remote_domain
{ name, certFrom }:
{ config, ... }:
let
  vars = config.clan.core.vars.generators.${name}.files;
  cert = config.clan.core.vars.generators.${certFrom}.files;
in
{
  services.sing-box.settings = {
    inbounds = [
      {
        type = "hysteria2";
        tag = "hysteria2-in";
        listen = "::";
        listen_port = 443;

        # salamander 混淆：QUIC 包在线路上不呈现 QUIC 特征（代价是客户端也要配同一份）
        obfs = {
          type = "salamander";
          password._secret = vars.obfs_password.path;
        };

        users = [
          {
            name = "urie";
            password._secret = vars.password.path;
          }
        ];

        tls = {
          enabled = true;
          certificate = [ cert.crt.value ];
          key_path = cert.key.path;
          server_name = cert.remote_domain.value;
        };

        # 认证失败/探测时的回应：sing-box 自己返回这个静态页，不需要 nginx。
        # 只对 QUIC(HTTP/3) 探测生效；自签证书下浏览器会先在证书这步拦下来。
        masquerade = {
          type = "string";
          status_code = 200;
          headers."content-type" = "text/html; charset=utf-8";
          content = ''
            <!doctype html>
            <html><head><meta charset="utf-8"><title>Welcome</title></head>
            <body><h1>It works!</h1></body></html>
          '';
        };
      }
    ];

    route.rules = [
      {
        inbound = "hysteria2-in";
        action = "route";
        outbound = "direct";
      }
    ];
  };
}
