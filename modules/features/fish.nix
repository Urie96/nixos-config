{ lib, ... }: {
  flake.nixosModules.fish =
    {
      pkgs,
      self',
      config,
      ...
    }:
    {
      programs.fish = {
        enable = true;
        package = self'.packages.fish;
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
      pkgs,
      config,
      self',
      ...
    }:
    {
      programs = {
        fish = {
          enable = true;
          package = self'.packages.fish;
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
    { config, self', ... }:
    {
      users.users.${config.my.mainUser.name}.shell = self'.packages.fish;
    };

  flake.droidModules.fish =
    {
      config,
      lib,
      self',
      ...
    }:
    {
      user.shell = lib.getExe config.programs.fish.package;
      programs.fish.enable = true;
      programs.fish.package = self'.packages.fish;
    };

}
