{
  flake.wrappers.fish =
    {
      wlib,
      lib,
      config,
      ...
    }:
    {
      imports = [ wlib.wrapperModules.fish ];

      options = {
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

      config = {
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
      };
    };
}
