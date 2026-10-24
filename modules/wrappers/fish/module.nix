{
  flake.wrappers.fish =
    {
      wlib,
      lib,
      config,
      pkgs,
      ...
    }:
    let
      direnvCfg = config.direnv;
      devenvCfg = config.devenv;

      tomlFormat = pkgs.formats.toml { };

      # direnv 只会读 $DIRENV_CONFIG/direnvrc，所以在里面把 nix-direnv 和用户自己的
      # 配置都 source 进来（布局与 nixpkgs 的 programs.direnv 生成的 /etc/direnv 一致）。
      direnvrc = pkgs.writeText "direnvrc" ''
        ${lib.optionalString direnvCfg.nix-direnv.enable ''
          # nix-direnv: 带缓存的 use_flake / use_nix
          source ${direnvCfg.nix-direnv.package}/share/nix-direnv/direnvrc
        ''}

        # direnvrcExtra
        ${direnvCfg.direnvrcExtra}

        # 用户自己的配置（~/.config/direnv/direnvrc 或 ~/.direnvrc）
        direnv_config_dir_home="''${DIRENV_CONFIG_HOME:-''${XDG_CONFIG_HOME:-$HOME/.config}/direnv}"
        if [[ -f $direnv_config_dir_home/direnvrc ]]; then
          source "$direnv_config_dir_home/direnvrc" >&2
        elif [[ -f $HOME/.direnvrc ]]; then
          source "$HOME/.direnvrc" >&2
        fi
        unset direnv_config_dir_home
      '';

      direnvConfig = pkgs.linkFarm "fish-direnv-config" (
        [
          {
            name = "direnvrc";
            path = direnvrc;
          }
        ]
        ++ lib.optional (direnvCfg.settings != { }) {
          name = "direnv.toml";
          path = tomlFormat.generate "direnv.toml" direnvCfg.settings;
        }
      );
    in
    {
      imports = [ wlib.wrapperModules.fish ];

      options = {
        direnv = {
          enable = lib.mkEnableOption ''
            direnv integration. Puts direnv on the wrapped fish' runtime PATH, sources
            `direnv hook fish` in interactive shells and points `DIRENV_CONFIG` at a
            wrapper-provided direnvrc (nix-direnv included)
          '';

          package = lib.mkPackageOption pkgs "direnv" { };

          nix-direnv = {
            enable =
              lib.mkEnableOption ''
                a faster, persistent implementation of use_nix and use_flake, replacing direnv's builtin one
              ''
              // {
                default = true;
              };

            package = lib.mkPackageOption pkgs "nix-direnv" { };
          };

          loadInNixShell = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether to load direnv inside `nix-shell`, `nix shell` or `nix develop`.
            '';
          };

          silent = lib.mkEnableOption ''
            the hiding of direnv logging
          '';

          direnvrcExtra = lib.mkOption {
            type = lib.types.lines;
            default = "";
            example = ''
              export FOO="foo"
              echo "loaded direnv!"
            '';
            description = ''
              Extra lines to append to the generated direnvrc
            '';
          };

          settings = lib.mkOption {
            inherit (tomlFormat) type;
            default = { };
            example = lib.literalExpression ''
              {
                global = {
                  log_format = "-";
                  log_filter = "^$";
                };
              }
            '';
            description = ''
              Direnv configuration, written to `$DIRENV_CONFIG/direnv.toml`.
              Refer to {manpage}`direnv.toml(1)`.
            '';
          };
        };

        devenv = {
          enable = lib.mkEnableOption ''
            devenv auto-activation. Puts devenv on the wrapped fish' runtime PATH and sources
            a fish hook that spawns a devenv shell on directory entry in interactive shells
          '';

          package = lib.mkPackageOption pkgs "devenv" { };

          hookFile = lib.mkOption {
            type = wlib.types.file pkgs;
            default.content = builtins.readFile ./devenv.fish;
            defaultText = lib.literalMD "`./devenv.fish`";
            description = ''
              Fish snippet which installs the devenv hook, sourced in interactive shells.

              Defaults to the copy vendored next to this module (patched so that exiting
              the devenv shell and `cd`-ing back does not re-activate). Override `content`
              or `path` to use another version of `devenv hook fish`.
            '';
          };
        };

        shellInit = lib.mkOption {
          default = "";
          description = ''
            Shell script code called during fish shell initialisation.
          '';
          type = lib.types.lines;
        };

        loginShellInit = lib.mkOption {
          default = "";
          description = ''
            Shell script code called during fish login shell initialisation.
          '';
          type = lib.types.lines;
        };

        interactiveShellInit = lib.mkOption {
          default = "";
          description = ''
            Shell script code called during interactive fish shell initialisation.
          '';
          type = lib.types.lines;
        };

        shellFunctions = lib.mkOption {
          description = ''
            A set of fish functions, with the attribute name being the function name. Function names cannot be reserved
            words or have spaces. These are elements of fish syntax or builtin commands which are essential for the
            operations of the shell.

            See the documentation for [fish functions](https://fishshell.com/docs/current/cmds/function.html) for further information.
          '';
          example = {
            ll.body = "ls -l $argv";
            mcd = {
              modifiers = {
                description = "Create a directory and set CWD";
              };
              body = ''
                command mkdir $argv
                if test $status = 0
                  switch $argv[(count $argv)]
                    case '-*'

                    case '*'
                      cd $argv[(count $argv)]
                      return
                  end
                end
              '';
            };
          };
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                body = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    The function body. You may provide a path or a string containing the fish function body.
                  '';
                };

                modifiers = lib.mkOption {
                  type = lib.types.attrsOf lib.types.anything;
                  default = { };
                  defaultText = "input for 'lib.cli.toCommandLine'";
                  description = ''
                    Modifiers to be applied to the function. This is a string, concatenated with a space after the function nane
                  '';
                };
              };

            }
          );
        };
      };

      config = lib.mkMerge [
        {
          configFile.content = ''
            if not set -q __wrapped_fish_general_config_sourced
              set fish_function_path "${placeholder config.outputName}/${config.binName}-functions" $fish_function_path
              ${config.shellInit}
              set -g __wrapped_fish_general_config_sourced 1
            end

            status is-login; and not set -q __wrapped_fish_login_config_sourced
            and begin
              ${config.loginShellInit}
              set -g __wrapped_fish_login_config_sourced 1
            end

            status is-interactive; and not set -q __wrapped_fish_interactive_config_sourced
            and begin
              ${config.interactiveShellInit}
              set -g __wrapped_fish_interactive_config_sourced 1
            end
          '';

          constructFiles = lib.mapAttrs' (name: value: {
            name = "function-${name}";
            value = {
              relPath = "${config.binName}-functions/${name}.fish";
              content =
                let
                  modifiers = lib.cli.toCommandLineShellGNU { } value.modifiers;
                in
                ''
                  function ${name} ${modifiers}
                    ${value.body}
                  end
                '';
            };
          }) config.shellFunctions;
        }

        (lib.mkIf direnvCfg.enable {
          # 让 `direnv allow` / `direnv status` 直接可用
          runtimePkgs = [ direnvCfg.package ];

          # 与 nixpkgs 的 programs.direnv 一致，但用 envDefault：
          # 系统已经把 DIRENV_CONFIG 指到 /etc/direnv（例如启用 programs.direnv）时让位，
          # 避免两套配置互相覆盖。
          envDefault.DIRENV_CONFIG = "${direnvConfig}";

          # 与 nixpkgs 的 programs.direnv 一致：不在 nix shell 里才加载
          # （direnv 会把手动进入的 nix shell 环境顶掉）。
          # 判断方式不同：nixpkgs 用“PATH 里不能出现 /nix/store”，这在 wrapper 里行不通
          # （wrapper 自己总会往 PATH 里加 store 路径，条件会永远为假），
          # 所以改用 nix-shell / nix develop 设置的 IN_NIX_SHELL。
          interactiveShellInit = ''
            if ${lib.boolToString direnvCfg.loadInNixShell}; or not set -q IN_NIX_SHELL
                ${lib.getExe direnvCfg.package} hook fish | source
            end
          '';

          direnv.settings = lib.mkIf direnvCfg.silent {
            global = {
              log_format = lib.mkDefault "-";
              log_filter = lib.mkDefault "^$";
            };
          };
        })

        (lib.mkIf devenvCfg.enable {
          # 让 `devenv` / `devenv allow` 等在 shell 里直接可用
          runtimePkgs = [ devenvCfg.package ];

          # devenv 用 fish_prompt 事件自动激活，位置无所谓，这里保持与原来一致的写法：
          # 找不到 devenv 时静默跳过，别每个 prompt 报错。
          interactiveShellInit = ''
            if command -q devenv
                source ${devenvCfg.hookFile.path}
            end
          '';
        })
      ];
    };
}
