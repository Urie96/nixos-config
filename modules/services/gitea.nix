# gitea 查看镜像github仓库的token：sudo cat /var/lib/gitea/repositories/urie/nixos-config.git/config
{ self, ... }:
{
  flake.nixosModules.gitea =
    { config, ... }:
    {
      services.gitea = {
        enable = true;
        settings.log.LEVEL = "Error";
        # 没有注册入口，首次装完要手动建管理员：
        #   GITEA=$(systemctl cat gitea | sed -n 's|^ExecStart=\(.*/bin/gitea\) .*|\1|p' | tail -1)
        #   sudo -u gitea env GITEA_WORK_DIR=/var/lib/gitea "$GITEA" admin user create \
        #     --admin --username <name> --email <mail>
        settings.service.DISABLE_REGISTRATION = true;
        # settings.metrics.ENABLED = true;
        settings.server = {
          DISABLE_ROUTER_LOG = true;
          ROOT_URL = "https://git.lubui.com:8443";
          # Gitea >= 1.26 defaults this to "auto", which builds absolute URLs
          # from the request's Host header. nginx's `$host` drops the :8443
          # port, so clone/PR/API links came out as https://git.lubui.com/...
          # "never" keeps using ROOT_URL as the authoritative public URL.
          PUBLIC_URL_DETECTION = "never";
          PROTOCOL = "http+unix";
          DISABLE_SSH = true;
        };
        settings.security = {
          # DISABLE_GIT_HOOKS = false;
        };
      };

      services.nginx.virtualHosts."git.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";
        locations."/".proxyPass = "http://unix:${config.services.gitea.settings.server.HTTP_ADDR}:/";
      };

    };

  flake.sysModules.gitea = { lib, ... }: {
    imports = [
      "${self.inputs.nixpkgs.outPath}/nixos/modules/services/misc/gitea.nix"
      self.sysModules.postgresql
    ];

    # system-manager 没有 mysql 模块，这里只声明一个空壳 option。
    # 真要用 mysql 得换成导入 nixpkgs 的 mysql 模块。
    options.services.mysql = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        system-manager 上的占位 option：gitea 模块无条件往 services.mysql 写定义，
        没有这个声明就没法求值。不要在 devbox 上依赖它做任何事。
      '';
    };

  };

}
