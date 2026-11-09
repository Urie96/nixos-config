# sing-box for Android 的订阅配置。
#
# 不在 Nix store 里落明文 secret：settings 里用 `_secret` 占位，systemd 服务启动时
# 用 nixpkgs 的 genJqSecretsReplacementSnippet 从 clan vars 读出真实值，写到
# /var/lib/nginx/singbox-subscription/android/<token>/config.json。
#
# 手机首次导入（推荐，直接打印 ASCII 二维码）：
#   nix run .#singbox-configuration -- home
#
# 之后配置更新由 SFA 轮询；App 里也可以直接添加 Remote profile 填上面的 URL。
{
  config,
  pkgs,
  utils,
  ...
}:
let
  sing-box-hk = config.clan.core.vars.generators.sing-box-hk.files;
  sing-box-kr = config.clan.core.vars.generators.sing-box-kr.files;
  sing-box-kr-reality = config.clan.core.vars.generators.sing-box-kr-reality.files;
  sing-box-kr-hysteria2 = config.clan.core.vars.generators.sing-box-kr-hysteria2.files;

  token = config.clan.core.vars.generators.singbox-android-subscription.files.token;

  settings = {
    log = {
      level = "error";
      timestamp = true;
    };
    dns = {
      servers = [
        {
          type = "tls";
          tag = "dns-proxy";
          detour = "proxy-out";
          server = "8.8.8.8";
        }
        {
          type = "udp";
          tag = "alidns";
          server = "223.5.5.5";
        }
      ];
      rules = [
        {
          rule_set = "geosite-category-ads-all";
          action = "reject";
          no_drop = true;
        }
        {
          rule_set = "geosite-cn";
          invert = true;
          server = "dns-proxy";
        }
      ];
      final = "alidns";
    };
    ntp = {
      enabled = true;
      server = "time.apple.com";
      server_port = 0;
    };
    # 远程 rule_set 走这个 client；detour 是 selector，默认 hysteria2-kr。
    http_clients = [
      {
        tag = "default-http";
        detour = "proxy-out";
      }
    ];
    inbounds = [
      {
        type = "tun";
        tag = "tun-in";
        interface_name = "tun0";
        address = [ "192.168.3.1/24" ];
        auto_route = true;
      }
    ];
    outbounds = import ./_client-outbounds.nix {
      inherit
        sing-box-hk
        sing-box-kr
        sing-box-kr-reality
        sing-box-kr-hysteria2
        ;
      default = "hysteria2-kr";
    };
    route = {
      rules = [
        {
          action = "sniff";
        }
        {
          protocol = "dns";
          action = "hijack-dns";
        }
        {
          ip_is_private = true;
          outbound = "direct-out";
        }
        {
          rule_set = "geoip-cn";
          outbound = "direct-out";
        }
        {
          rule_set = "geosite-cn";
          outbound = "direct-out";
        }
      ];
      # Android 上没有 /nix/store，规则集必须是 remote；首次下载走 default-http。
      rule_set = [
        {
          type = "remote";
          tag = "geoip-cn";
          format = "binary";
          url = "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs";
        }
        {
          type = "remote";
          tag = "geosite-cn";
          format = "binary";
          url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs";
        }
        {
          type = "remote";
          tag = "geosite-category-ads-all";
          format = "binary";
          url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs";
        }
      ];
      final = "proxy-out";
      auto_detect_interface = true;
      default_domain_resolver = "alidns";
      default_http_client = "default-http";
    };
    experimental.cache_file = {
      enabled = true;
      path = "cache.db";
    };
  };

  # 这个片段会把 settings 里的 `_secret` 替换成对应文件的内容，输出 JSON。
  render = utils.genJqSecretsReplacementSnippet settings "/var/lib/nginx/singbox-subscription/config.json.tmp";

  # 这些文件内容变了就要重新渲染；token 变了同时会换 URL。
  secretPaths = [
    token.path
    sing-box-hk.uuid.path
    sing-box-kr.uuid.path
    sing-box-kr-hysteria2.password.path
    sing-box-kr-hysteria2.obfs_password.path
  ];
in
{
  clan.core.vars.generators.singbox-android-subscription = {
    share = true;
    files.token = { };
    runtimeInputs = with pkgs; [ openssl ];
    script = ''
      openssl rand -hex 32 > $out/token
    '';
  };

  systemd.services.singbox-android-subscription = {
    description = "Generate sing-box Android subscription config";
    wantedBy = [ "multi-user.target" ];
    before = [ "nginx.service" ];
    restartTriggers = secretPaths;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      set -euo pipefail

      token=$(cat ${token.path})
      configDir="/var/lib/nginx/singbox-subscription/android/$token"
      tmp="/var/lib/nginx/singbox-subscription/config.json.tmp"

      install -d -o ${config.services.nginx.user} -g ${config.services.nginx.group} -m 0700 \
        /var/lib/nginx/singbox-subscription/android
      install -d -o ${config.services.nginx.user} -g ${config.services.nginx.group} -m 0700 "$configDir"

      rm -f "$tmp"
      ${render}
      ${config.services.sing-box.package}/bin/sing-box check -c "$tmp"
      install -o ${config.services.nginx.user} -g ${config.services.nginx.group} -m 0400 "$tmp" "$configDir/config.json"
      rm -f "$tmp"

      # 只保留当前 token 的目录，旧二维码立即失效
      find /var/lib/nginx/singbox-subscription/android -mindepth 1 -maxdepth 1 -type d \
        ! -name "$token" -exec rm -rf {} +
    '';
  };

  services.nginx.virtualHosts."singbox.lubui.com".locations."/android/" = {
    priority = 200;
    root = "/var/lib/nginx/singbox-subscription";
    extraConfig = ''
      # SFA 不会走 Authelia 登录；这个 location 只靠 URL 里的随机 token 保护。
      auth_request off;
      access_log off;
      autoindex off;
      default_type application/json;
      add_header Cache-Control "no-store, no-cache, must-revalidate";
    '';
  };
}
