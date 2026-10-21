{ lib, ... }: {
  flake.nixosModules.fish =
    {
      pkgs,
      config,
      ...
    }:
    {
      programs.fish = {
        enable = true;
        package = config.wrappers.fish.wrapper;
        useBabelfish = true;
      };

      users.users.urie.shell = config.programs.fish.package;

      # shadows better builtin completions
      environment.etc."fish/generated_completions".source = lib.mkForce (
        pkgs.writeText "fish-completions" ''
          mkdir $out
        ''
      );
    };

  flake.darwinModules.fish =
    {
      config,
      ...
    }:
    {
      programs = {
        fish = {
          enable = true;
          package = config.wrappers.fish.wrapper;
          useBabelfish = true;
        };
        # direnv = {
        #   enable = true;
        #   nix-direnv.enable = true;
        # };
      };

      users.users.${config.system.primaryUser}.shell = config.programs.fish.package;
    };

  flake.sysModules.fish =
    { config, ... }:
    {
      users.users.${config.my.mainUser.name}.shell = config.wrappers.fish.wrapper;
    };

  flake.droidModules.fish =
    {
      config,
      lib,
      ...
    }:
    {
      user.shell = lib.getExe config.programs.fish.package;
      programs.fish.enable = true;
      programs.fish.package = config.wrappers.fish.wrapper;
    };

}
