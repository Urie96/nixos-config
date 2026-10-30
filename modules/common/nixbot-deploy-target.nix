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
      users.users.root =
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          uid = 0;
          gid = 0;
        }
        // {
          openssh.authorizedKeys.keys = lib.optional pub.exists (lib.trim pub.value);
        };
    };
in
{
  flake.nixosModules.common = nixbotDeployTarget;
  flake.darwinModules.common = nixbotDeployTarget;
}
