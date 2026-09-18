{
  flake.nixosModules.notify-on-systemd-failure =
    {
      pkgs,
      self',
      lib,
      ...
    }:
    let
      packages = self'.packages;
    in
    {
      systemd.services."notify-failed@" = {
        description = "notify that %i has failed";
        scriptArgs = "%i";
        script = ''
          unit=$1
          journalctl -u "$unit" -n 15 | ${lib.getExe packages.notify-me} -t "Systemd $unit failed"
        '';
      };
    };
}
