{ self, ... }:
let
  root_url = "https://git.lubui.com:8443";

  gitea-runner-token =
    { pkgs, ... }:
    {
      clan.core.vars.generators.gitea-runner-token = {
        share = true;
        files = {
          gitea_env = { };
          runner_env = { };
        };
        runtimeInputs = [ pkgs.openssl ];
        script = ''
          token="$(openssl rand -hex 32)"
          printf 'GITEA_RUNNER_REGISTRATION_TOKEN=%s\n' "$token" > "$out/gitea_env"
          printf 'TOKEN=%s\n' "$token" > "$out/runner_env"
        '';
      };
    };

  mkRunnerConfig = { pkgs, config, ... }: {
    enable = true;
    name = "runner";
    url = root_url;
    tokenFile = config.clan.core.vars.generators.gitea-runner-token.files.runner_env.path;
    # 末尾的 :host 必须保留：模块只有检测到 *:host 才会把 hostPackages 加进 PATH。
    labels = [ "${pkgs.stdenv.hostPlatform.system}:host" ];
    hostPackages = with pkgs; [
      bash
      curl
      gawk
      gitMinimal
      jq
      nix
      nodejs
      wget
      tea
      openssh
      diffutils
    ];
  };
in
{
  flake.nixosModules.gitea-runner-home =
    { config, pkgs, ... }@args:
    {
      # NixOS 自带 services.gitea-actions-runner（module-list 里已导入），
      # 这里不要再导入 flake.darwinModules.gitea-runner（那是 launchd 实现）。
      imports = [
        gitea-runner-token
      ];

      services.gitea-actions-runner.instances.runner = mkRunnerConfig args;

      # token 由 clan shared vars 生成，nix store 里只出现 EnvironmentFile 的路径。
      systemd.services.gitea.serviceConfig.EnvironmentFile =
        config.clan.core.vars.generators.gitea-runner-token.files.gitea_env.path;
    };

  flake.darwinModules.gitea-runner-home =
    { config, pkgs, ... }@args:
    {
      imports = [
        gitea-runner-token
        self.darwinModules.gitea-runner
      ];

      clan.core.vars.generators.gitea-runner-token.files.runner_env.owner =
        config.services.gitea-actions-runner.instances.runner.user;

      services.gitea-actions-runner.instances.runner = mkRunnerConfig args;
    };
}
