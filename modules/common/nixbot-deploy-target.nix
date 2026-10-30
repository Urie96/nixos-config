{ ... }:
let
  # nixbot 自动部署用的 SSH key：nixbot 在 home-server 上跑 `onPush` effect
  # （modules/ci.nix），以 root 身份登录目标机切换配置。
  #
  # 同一个 module 同时导出成 nixosModules 和 darwinModules：clan vars 的**共享**
  # 生成器要求各机器上的定义完全一致（CLI 会对比 share/dependencies/script/files），
  # 复用同一个函数就不会漂。
  #
  # 为什么私钥 deploy = false：clan vars 的 deploy 标志没法按机器区分（共享生成器
  # 定义不一致时 CLI 直接报错），所以私钥「谁都不部署」。真正的下发路径是
  # home-server 自己的 per-machine 生成器 `nixbot-deploy-secrets`
  # （modules/services/nixbot.nix）：它把共享私钥读出来包成 nixbot 要的 effects
  # secrets JSON，所以只有 home-server 拿得到私钥。
  #
  # 公钥是明文 public var（secret = false），在求值期读进目标机 root 的
  # authorized_keys；`exists` 判断保证还没生成时不会把整机 eval 打挂。
  #
  # 首次使用：
  #   clan vars generate home-server -g nixbot-deploy
  #   clan vars generate home-server -g nixbot-deploy-secrets
  # 之后 vars/shared/nixbot-deploy/private-key.pub/value 要提交进 git（flake 源）。
  nixbotDeployTarget =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      pub = config.clan.core.vars.generators.nixbot-deploy.files."private-key.pub";
    in
    {
      clan.core.vars.generators.nixbot-deploy = {
        share = true;
        files."private-key".deploy = false;
        files."private-key.pub" = {
          secret = false;
          deploy = false;
        };
        runtimeInputs = [ pkgs.openssh ];
        script = ''
          ssh-keygen -q -t ed25519 -N "" -C nixbot-deploy -f "$out/private-key"
        '';
      };

      # nix-darwin 里 users.users.root 只有在本模块给出 uid/gid 时才不会被当成
      # 需要 sysadminctl 创建的新账号（mac-mini 已经由 nix-builders-builder 定义过，
      # 这里给同样的值只是让本模块可以单独复用）。
      #
      users.users.root =
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          uid = 0;
          gid = 0;
        }
        // {
          openssh.authorizedKeys.keys = lib.optional pub.exists (lib.trim pub.value);
        };

      # 把 root 的登录 shell 改成 zsh，否则 nixbot 的 darwin 部署连不上：
      # runNixDarwin 用 `nix-copy-closure --to root@<host>`，它执行的是
      # `ssh root@<host> -- nix-store --serve --write`。sshd 用 root 的登录 shell
      # 以**非登录、非交互**方式跑这条命令，而 macOS 上 root 默认是 /bin/sh：
      # sh 在这种模式下不读 /etc/profile、/etc/bashrc、/etc/zshenv，PATH 只剩
      # /usr/bin:/bin:/usr/sbin:/sbin，于是报 `sh: nix-store: command not found`
      # （同一现象：`nix store info --store ssh://root@<host>`）。
      #
      # 为什么是 zsh：nix-darwin 把 PATH 写进 /etc/zshenv，而 zsh 对**所有**调用
      # （包括 `zsh -c`）都会读 /etc/zshenv；bash 的 /etc/bashrc 只在交互时读，
      # sh 两个都不读。
      #
      # 为什么不用 users.users.root.shell：nix-darwin 只对 users.knownUsers 里的
      # 用户生成 `dscl . -create ... UserShell`（见 nix-darwin modules/users），
      # 而 root 故意不纳管（modules/system/nix-builders.nix 有说明），写了是死配置。
      #
      # NixOS 目标机不需要这段：NixOS 的 sshd unit 自带 /run/current-system/sw/bin
      # 的 PATH；clan 也不需要：它给 darwin 的 store URL 拼了
      # `?remote-program=bash -lc 'exec nix-daemon --stdio'`（见 clan-cli
      # clan_lib/machines/update.py），只有 nix-copy-closure 没法传这个参数。
      system = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        # nix-darwin 只执行固定名字的激活脚本（见 nix-darwin
        # modules/system/activation-scripts.nix），所以这里挂在 postActivation 上，
        # 自定义名字不会被运行。
        activationScripts.postActivation.text = lib.mkAfter ''
          /usr/bin/dscl . -create /Users/root UserShell /bin/zsh
        '';
      };
    };
in
{
  flake.nixosModules.common = nixbotDeployTarget;
  flake.darwinModules.common = nixbotDeployTarget;
}
