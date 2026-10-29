{ self, ... }:
let
  mkRunnerConfig = { config, pkgs, ... }: name: {
    enable = true;
    name = name;
    url = "http://10.37.107.28:3000/";
    tokenFile = config.sops.templates."gitea-runner-token.env".path;
    labels = [ "${pkgs.stdenv.hostPlatform.system}:host" ];
    hostPackages = with pkgs; [
      bash
      coreutils
      curl
      gawk
      gitMinimal
      gnused
      jq
      config.nix.package
      nodejs
      openssh
      wget
      diffutils
    ];
  };
in

{
  flake.darwinModules.gitea-runner-work =
    {
      config,
      lib,
      pkgs,
      ...
    }@args:
    {
      imports = with self.darwinModules; [
        gitea-runner
      ];

      services.gitea-actions-runner.instances.runner.enable = lib.mkForce false;

      services.gitea-actions-runner.instances.mac-runner = mkRunnerConfig args "mac-runner";

      sops.secrets.gitea-runner-token = { };
      sops.templates."gitea-runner-token.env" = {
        owner = "_gitea-runner"; # 与 runner 的运行用户一致
        content = ''
          GITEA_RUNNER_REGISTRATION_TOKEN=${config.sops.placeholder.gitea-runner-token}
          TOKEN=${config.sops.placeholder.gitea-runner-token}
        '';
      };
    };

  flake.sysModules.gitea-runner-work =
    { config, pkgs, ... }@args:
    {
      imports = with self.sysModules; [
        gitea-runner
      ];

      sops.secrets.gitea-runner-token = { };
      sops.templates."gitea-runner-token.env" = {
        content = ''
          GITEA_RUNNER_REGISTRATION_TOKEN=${config.sops.placeholder.gitea-runner-token}
          TOKEN=${config.sops.placeholder.gitea-runner-token}
        '';
      };

      services.gitea-actions-runner.instances.devbox = mkRunnerConfig args "devbox";

      systemd.services.gitea.serviceConfig.EnvironmentFile =
        config.sops.templates."gitea-runner-token.env".path;

      systemd.services."gitea-runner-devbox".serviceConfig.SupplementaryGroups = [ "nix-tokens" ];
      systemd.services."gitea-runner-devbox".environment =
        let
          proxy = "http://sys-proxy-rd-relay.byted.org:8118";
          no_proxy = "10.37.107.28,localhost,127.0.0.1,.byted.org,.bytedance.net";
        in
        {
          http_proxy = proxy;
          https_proxy = proxy;
          all_proxy = proxy;
          HTTP_PROXY = proxy;
          HTTPS_PROXY = proxy;
          ALL_PROXY = proxy;
          no_proxy = no_proxy;
          NO_PROXY = no_proxy;
        };
    };
}
