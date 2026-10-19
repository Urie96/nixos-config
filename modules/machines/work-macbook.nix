{
  clan.inventory.machines.work-macbook.machineClass = "darwin";

  clan.machines.work-macbook =
    {
      config,
      inputs',
      lib,
      self,
      pkgs,
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
    in
    {
      imports = with self.darwinModules; [
        full
        disable-awdl
        gitea-runner
      ];

      environment.variables = {
        WORK = "1";
      };

      environment.systemPackages = with inputs'.nur-packages.packages; [
        feishu
      ];

      services.gitea-actions-runner.instances.runner.enable = lib.mkForce false;

      services.gitea-actions-runner.instances.mac-runner = {
        enable = true;
        name = "mac-runner";
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

      sops = {
        age.keyFile = "/Users/${config.system.primaryUser}/.config/sops/age/keys.txt";
        secrets.gitea-runner-token.sopsFile = ./devbox/secrets.yaml;
      };

      sops.templates."gitea-runner-token.env" = {
        owner = "_gitea-runner"; # 与 runner 的运行用户一致
        content = ''
          GITEA_RUNNER_REGISTRATION_TOKEN=${config.sops.placeholder.gitea-runner-token}
          TOKEN=${config.sops.placeholder.gitea-runner-token}
        '';
      };

      # `clan machines update` 不带机器名时跳过它，
      clan.core.deployment.requireExplicitUpdate = true;

      system.primaryUser = "bytedance";
      system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = true;
      users.users.bytedance.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWZOsC6Mx+q9rNcK/EvY5/WIJ86BDJkd/V5i+6F3qZb yangrui.0@bytedance.com"
      ];

      launchd.user.agents.confetti = {
        serviceConfig = {
          StartCalendarInterval = [
            {
              Hour = 11;
              Minute = 55;
            }
            {
              Hour = 17;
              Minute = 55;
            }
            {
              Hour = 21;
              Minute = 29;
            }
          ];
          ProgramArguments = [
            "${nur.confetti}/bin/confetti"
          ];
        };
      };

      system.stateVersion = 5;
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
}
