{ lib, ... }:
let
  commonOptions = {
    options = {
      my.mainUser = {
        name = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "The username of the primary user for this system.";
        };
      };

      my.homeNetwork = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether this machine sits on the home network. When true, hosts on
          the home LAN are reachable directly, so no SSH jump host is needed.
        '';
      };
    };
  };
in
{
  flake.nixosModules.common = commonOptions;
  flake.darwinModules.common = commonOptions;
  flake.sysModules.common = commonOptions;
  flake.droidModules.common = commonOptions;
}
