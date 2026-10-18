{ self, ... }:
# 别处（orangepi5plus / mac-mini）构建的包要能进这台机器的 store：harmonia 是只读
# 缓存，没有 upload 接口，所以只能由对方 `nix copy` 推进来。
#
# 推进入口是一个受限 ssh 用户：authorized_keys 里只允许 `nix-daemon --stdio`
# （nix 的 ssh-ng store 就是连这个），并且它不在 trusted-users 里 —— daemon 会按
# require-sigs 校验签名，所以「有缓存签名 key 的签名」就是准入控制。
{
  flake.nixosModules.cache-push =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # 缓存签名 key 的名字，从共享的签名公钥变量里取（"<name>:<pubkey>"）。
      # 推送的包是构建机用这把 key 签的。
      signingKeyName = lib.head (
        lib.splitString ":" config.clan.core.vars.generators.nix-signing.files."nix-signing.pub".value
      );

      # ssh-keygen 的公钥文件带结尾换行，去掉以免 authorized_keys 里出现空行。
      pushPubKey = lib.trim config.clan.core.vars.generators.cache-push.files."cache-push.pub".value;
    in
    {
      imports = [
        self.nixosModules.nix-signing
      ];

      # 两个约束：主组不能是 nixbld（nix daemon 会直接拒绝连接）；shell 不能是
      # nologin（sshd 用用户 shell 执行 authorized_keys 里的强制命令）。
      users.groups.cache-push = { };
      users.users.cache-push = {
        isSystemUser = true;
        group = "cache-push";
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [
          ''restrict,command="${config.nix.package}/bin/nix-daemon --stdio" ${pushPubKey}''
        ];
      };

      # 私钥不进任何机器的 /run/secrets（deploy = false），推送时由 workflow 从
      # Gitea 的 Actions secret 注入；需要取出来时：
      #   clan vars get home-server cache-push/cache-push.key
      clan.core.vars.generators.cache-push = {
        files."cache-push.key".deploy = false;
        files."cache-push.pub".secret = false;
        runtimeInputs = [ pkgs.openssh ];
        script = ''
          ssh-keygen -q -t ed25519 -N "" -C cache-push -f "$out/cache-push.key"
          mv "$out/cache-push.key.pub" "$out/cache-push.pub"
        '';
      };

      # 公钥必须在 trusted-public-keys 里（modules/system/nix-daemon.nix 提供）。
      assertions = [
        {
          assertion = lib.any (
            key: lib.hasPrefix "${signingKeyName}:" key
          ) config.nix.settings.trusted-public-keys;
          message = ''
            ${signingKeyName} 的签名公钥不在 nix.settings.trusted-public-keys 里，
            推上来的路径会因「lacks a signature by a trusted key」被拒绝。
          '';
        }
      ];
    };
}
