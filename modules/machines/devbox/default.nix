{ self, ... }:
{
  perSystem =
    {
      mkSystemManagerConfig,
      ...
    }:
    {
      legacyPackages.systemConfigs.devbox = mkSystemManagerConfig {
        modules =
          (with self.sysModules; [
            full
            sops
            harmonia
            work
            gitea-work
            gitea-runner-work
            niks3-work
            nix-access-token
          ])
          ++ [
            (
              {
                config,
                pkgs,
                lib,
                ...
              }:
              let
                username = "yangrui.0";
                home = "/home/${username}";

                # 内网出口代理：runner 从 github 拉 action 仓库超时，要让 runner 进程
                # （以及它 fork 出去的 git/node）走这个代理。
                proxy = "http://sys-proxy-rd-relay.byted.org:8118";
                no_proxy = "10.37.107.28,localhost,127.0.0.1,.byted.org,.bytedance.net";
              in
              {
                my.mainUser.name = username;
                home-manager.users.${username}.programs.ssh.settings."code.byted.org" = {
                  IdentityFile = "~/.ssh/id_ed25519";
                  IdentitiesOnly = "yes";
                  User = "git";
                };

                sops = {
                  age.keyFile = "${home}/.config/sops/age/keys.txt";
                  defaultSopsFile = ./secrets.yaml;
                };

                # nix-daemon 的 /etc/systemd/system/nix-daemon.service 是官方安装脚本放的
                # 符号链接（→ /nix/var/nix/profiles/default/...），仓库不接管这个 unit 文件，
                # 只加一个 drop-in 覆盖它的环境变量：
                #
                #   · 不用 systemd.services.nix-daemon：那会让 system-manager 试图自己写
                #     /etc/systemd/system/nix-daemon.service，而 etc 激活对「已存在且非
                #     system-manager 管理的文件」只会 warn 然后跳过（.wants/.requires 例外），
                #     结果 unit 没被接管、drop-in 也没生成。
                #   · replaceExisting 必须为 true：这份 override.conf 目前是手写的，不置位
                #     同样只会 warn 跳过；旧文件会被备份成
                #     override.conf.system-manager-backup（systemd 不读非 *.conf，无副作用）。
                environment.etc."systemd/system/nix-daemon.service.d/override.conf" = {
                  replaceExisting = true;
                  text = ''
                    [Service]
                    Environment=http_proxy=${proxy}
                    Environment=https_proxy=${proxy}
                    Environment=no_proxy=${no_proxy}
                  '';
                };
              }
            )
          ];
      };
    };
}
