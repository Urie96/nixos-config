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
    };
  };
in
{
  flake.nixosModules.common = commonOptions;
  flake.sysModules.common = commonOptions;
  flake.droidModules.common = commonOptions;
}
