{
  flake.nixosModules.home =
    {
      config,
      self,
      inputs',
      self',
      ...
    }:
    {
      imports = [
        self.inputs.home-manager.nixosModules.home-manager
      ];

      home-manager = {
        extraSpecialArgs = {
          inherit
            self
            self'
            inputs'
            ;
        };
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${config.my.mainUser.name} = self.homeModules.common;
        backupFileExtension = "backup";
      };
    };

  flake.darwinModules.home =
    {
      self,
      config,
      self',
      inputs',
      ...
    }:
    {
      imports = [
        self.inputs.home-manager.darwinModules.home-manager
      ];

      home-manager = {
        extraSpecialArgs = {
          inherit
            self
            self'
            inputs'
            ;
        };
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${config.system.primaryUser} = self.homeModules.common;
        backupFileExtension = "backup";
      };
    };

  flake.sysModules.home =
    {
      self,
      self',
      inputs',
      config,
      ...
    }:
    {
      imports = [
        self.inputs.home-manager.nixosModules.home-manager
      ];

      home-manager = {
        extraSpecialArgs = {
          inherit
            self
            self'
            inputs'
            ;
        };
        users."${config.my.mainUser.name}" = self.homeModules.common;
      };
    };

  flake.homeModules.common =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home.homeDirectory = lib.mkDefault (
        if pkgs.stdenv.hostPlatform.isDarwin then
          "/Users/${config.home.username}"
        else
          "/home/${config.home.username}"
      );

      # better eval time
      manual.html.enable = false;
      manual.manpages.enable = false;
      manual.json.enable = false;

      home.enableNixpkgsReleaseCheck = false;

      home.stateVersion = "26.05";
    };

  flake.droidModules.home =
    {
      self,
      self',
      inputs',
      ...
    }:
    {
      home-manager = {
        backupFileExtension = "backup";
        useGlobalPkgs = true;
        useUserPackages = true;
        # `flake.homeModules.*` refer to `flake` in their own arguments (and
        # sometimes in `imports`), so it has to be provided as a specialArg.
        # Home Manager submodules do not inherit args from their parent, and
        # resolving an arg through `_module.args` needs `config`, which is an
        # infinite recursion when the arg is used in `imports` (nixos/darwin
        # home modules do the same).
        extraSpecialArgs = {
          inherit
            self
            self'
            inputs'
            ;
        };
        config = { config, pkgs, ... }: {
          imports = [
            self.homeModules.common
            ({
              home.file."${config.home.homeDirectory}/.terminfo/x/xterm-kitty".source =
                "${pkgs.kitty.terminfo}/share/terminfo/x/xterm-kitty";
            })
          ];
        };
      };
    };
}
