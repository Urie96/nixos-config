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
              }
            )
          ];
      };
    };
}
