{
  # `hm` 是当前主用户 Home Manager 配置的短别名：
  #   nixos / darwin / sys -> home-manager.users.${config.my.mainUser.name}
  #   nix-on-droid        -> home-manager.config（没有 users）
  flake.nixosModules.home =
    {
      config,
      lib,
      self,
      inputs',
      self',
      ...
    }:
    {
      imports = [
        self.inputs.home-manager.nixosModules.home-manager
        (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "users" config.my.mainUser.name ])
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
      config,
      lib,
      self,
      self',
      inputs',
      ...
    }:
    {
      imports = [
        self.inputs.home-manager.darwinModules.home-manager
        (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "users" config.my.mainUser.name ])
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
      lib,
      self,
      self',
      inputs',
      config,
      ...
    }:
    {
      imports = [
        self.inputs.home-manager.nixosModules.home-manager
        (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "users" config.my.mainUser.name ])
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
      self,
      ...
    }:
    {
      imports = [ self.homeModules.git ];

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
      lib,
      self,
      self',
      inputs',
      config,
      ...
    }:
    {
      imports = [
        # nix-on-droid 没有 users，HM 配置直接放在 home-manager.config。
        (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "config" ])
      ];

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
          # nix-on-droid 的 home-manager 模块不像 home-manager 的 nixos/darwin
          # 模块那样自动注入 osConfig，这里手动补上，让 home 模块能读取 my.* 主机选项。
          osConfig = config;
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
