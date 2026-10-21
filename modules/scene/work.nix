{ lib, ... }:
{
  flake.darwinModules.work = {
    environment.variables = {
      WORK = "1";
    };

    wrappers.git.settings.user = {
      name = lib.mkForce "yangrui.0";
      email = lib.mkForce "yangrui.0@bytedance.com";
    };
  };

  flake.sysModules.work = {
    environment.variables = {
      WORK = "1";
    };

    wrappers.git.settings.user = {
      name = lib.mkForce "yangrui.0";
      email = lib.mkForce "yangrui.0@bytedance.com";
    };
  };
}
