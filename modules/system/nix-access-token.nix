{
  flake.sysModules.nix-access-token = { config, ... }: {
    sops.secrets = {
      github-token-rate-limit = { };
    };

    nix.extraOptions = ''
      !include ${config.sops.templates.nixAccessTokens.path}
    '';

    # nix.conf 的这个 include 文件里有明文 token，不能给所有用户读。
    # 建一个共享组：yangrui.0 直接加进去，gitea runner 是 DynamicUser
    # （运行时才分配 uid/gid），只能用 SupplementaryGroups 加入静态组。
    users.groups.nix-tokens = { };
    users.users.${config.my.mainUser.name}.extraGroups = [ "nix-tokens" ];

    sops.templates.nixAccessTokens = {
      mode = "0440";
      group = "nix-tokens";
      content = ''
        access-tokens = github.com=${config.sops.placeholder.github-token-rate-limit}
      '';
    };
  };
}
