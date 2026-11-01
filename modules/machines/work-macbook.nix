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
        work
        gitea-runner-work
        # 拉取式自动部署：这台不在局域网里，nixbot 推不进来，改成定时拉
        # cache.lubui.com 上的 desired-state 清单、比较、拉闭包并激活。
        pull-deploy
      ];

      pullDeploy = {
        enable = true;
        machine = "work-macbook";
      };

      homebrew.casks = [ "feishu" ];

      sops = {
        age.keyFile = "/Users/${config.system.primaryUser}/.config/sops/age/keys.txt";
        secrets.gitea-runner-token.sopsFile = ./devbox/secrets.yaml;
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
