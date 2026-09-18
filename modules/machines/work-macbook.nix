{
  clan.inventory.machines.work-macbook.machineClass = "darwin";

  clan.machines.work-macbook =
    {
      inputs',
      self,
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
    in
    {
      imports = with self.darwinModules; [
        full
        disable-awdl
      ];

      environment.variables = {
        WORK = "1";
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
