{ self, ... }:
{
  flake.sysModules.gitea-work = { config, pkgs, ... }: {
    imports = with self.sysModules; [
      gitea
    ];

    services.gitea = {
      enable = true;
      settings = {
        log.LEVEL = "Error";
        service.DISABLE_REGISTRATION = false;
        # Gitea 28 的迁移/镜像出口策略（modules/egress）：默认 EGRESS_MODE = lax 只放行公网地址，
        # 内网/回环/CGNAT 必须显式允许，且 28.2 起只认 IP/CIDR 或内置别名 private/loopback，写域名无效。
        # 用内置别名 private（10/8、172.16/12、192.168/16、fc00::/7、CGNAT 100.64/10），
        # 覆盖 code.byted.org 的 10.8.7.149 和 fdbd:dc01:fe:200f::1，IP 变更也不用改配置。
        migrations.ALLOWED_HOST_LIST = "private";
        server = {
          ROOT_URL = "http://10.37.107.28:3000/";
          HTTP_PORT = 3000;
          HTTP_ADDR = "0.0.0.0";
          DISABLE_ROUTER_LOG = true;
          DISABLE_SSH = true;
          PUBLIC_URL_DETECTION = "never";
        };
      };
    };
  };
}
