{ self, ... }:
{
  perSystem =
    {
      mkSystemManagerConfig,
      ...
    }:
    {
      legacyPackages.systemConfigs.devbox = mkSystemManagerConfig {
        modules = [
          self.sysModules.full
          self.sysModules.sops
          self.sysModules.harmonia
          self.sysModules.niks3
          self.sysModules.gitea
          self.sysModules.gitea-runner
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

              sops.secrets = {
                nix-sign.owner = "niks3";
                niks3-ak.owner = "niks3";
                niks3-sk.owner = "niks3";
                niks3-api-token.owner = "niks3";
                gitea-runner-token = { };
                github-token-rate-limit = { };
              };

              nix.extraOptions = ''
                !include ${config.sops.templates.nixAccessTokens.path}
              '';

              # nix.conf 的这个 include 文件里有明文 token，不能给所有用户读。
              # 建一个共享组：yangrui.0 直接加进去，gitea runner 是 DynamicUser
              # （运行时才分配 uid/gid），只能用 SupplementaryGroups 加入静态组。
              users.groups.nix-tokens = { };
              users.users.${username}.extraGroups = [ "nix-tokens" ];

              sops.templates.nixAccessTokens = {
                mode = "0440";
                group = "nix-tokens";
                content = ''
                  access-tokens = github.com=${config.sops.placeholder.github-token-rate-limit}
                '';
              };

              # 同一个 token 渲染成服务端 + runner 都能用的环境文件（KEY=VALUE）：
              # sops 会把明文 token 在激活时替换进去，文件本身不会进 nix store。
              sops.templates."gitea-runner-token.env" = {
                content = ''
                  GITEA_RUNNER_REGISTRATION_TOKEN=${config.sops.placeholder.gitea-runner-token}
                  TOKEN=${config.sops.placeholder.gitea-runner-token}
                '';
              };

              services.niks3 = {
                enable = true;
                httpAddr = "0.0.0.0:5751";
                s3 = {
                  endpoint = "tos-s3-cn-north.byted.org";
                  bucket = "niks3";
                  region = "china-north";
                  accessKeyFile = config.sops.secrets.niks3-ak.path;
                  secretKeyFile = config.sops.secrets.niks3-sk.path;
                };
                apiTokenFile = config.sops.secrets.niks3-api-token.path;
                signKeyFiles = [ config.sops.secrets.nix-sign.path ];
              };

              services.gitea = {
                enable = true;
                settings = {
                  log.LEVEL = "Error";
                  service.DISABLE_REGISTRATION = false;
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

              # Gitea Actions：devbox 不是 clan 机器，用不了 selfhost 那套
              # clan.core.vars 的共享 token，改用 sops secret（gitea-runner-token，
              # 明文 token），再经 sops.templates 渲染成上面那个环境文件：服务端读
              # GITEA_RUNNER_REGISTRATION_TOKEN，runner 读 TOKEN。
              systemd.services.gitea = {
                # 渲染在 sops-install-secrets 阶段（Before=sysinit.target）就绪，
                # gitea 启动时一定在；不用 - 前缀。
                serviceConfig.EnvironmentFile = config.sops.templates."gitea-runner-token.env".path;
              };

              services.gitea-actions-runner.instances.devbox = {
                enable = true;
                name = "devbox";
                url = "http://10.37.107.28:3000/";
                tokenFile = config.sops.templates."gitea-runner-token.env".path;
                # 与 selfhost 的 runner 用同一套标签；末尾的 :host 必须保留，
                # 模块只有检测到 *:host 才会把 hostPackages 加进 PATH。
                labels = [ "${pkgs.stdenv.hostPlatform.system}:host" ];
                hostPackages = with pkgs; [
                  bash
                  coreutils
                  curl
                  gawk
                  gitMinimal
                  gnused
                  jq
                  # 用 daemon 同一个 nix：runner 以 DynamicUser 运行，走 nix-daemon 构建。
                  config.nix.package
                  nodejs
                  openssh
                  wget
                  diffutils
                ];
              };

              # 上游 gitea-actions-runner 模块没有 proxy 选项，直接给生成的
              # systemd 服务追加环境变量（environment 是 attrset，会和模块自己写的
              # HOME/TOKEN 合并）。runner 拉 action、job 里的 git/curl/node 都会继承。
              # 大小写都设：Go（runner 本体 + go-git）认小写，node/部分 action 认大写。
              # no_proxy 必须带上 gitea 自己的地址 10.37.107.28，否则注册/心跳会被
              # 送进代理，runner 连不上服务端。
              systemd.services."gitea-runner-devbox".serviceConfig.SupplementaryGroups = [ "nix-tokens" ];
              systemd.services."gitea-runner-devbox".environment = {
                http_proxy = proxy;
                https_proxy = proxy;
                all_proxy = proxy;
                HTTP_PROXY = proxy;
                HTTPS_PROXY = proxy;
                ALL_PROXY = proxy;
                no_proxy = "code.byted.org,10.37.107.28,localhost,127.0.0.1,*.byted.org";
                NO_PROXY = "code.byted.org,10.37.107.28,localhost,127.0.0.1,*.byted.org";
              };

            }
          )
        ];
      };
    };
}
