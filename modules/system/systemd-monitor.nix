{
  flake.nixosModules.systemd-monitor =
    {
      config,
      pkgs,
      self',
      lib,
      ...
    }:
    let
      name = "systemd-monitor";
    in
    {
      systemd.timers.${name} = {
        wantedBy = [ "timers.target" ];
        after = [ "network.target" ];
        timerConfig = {
          OnCalendar = "*:0/10";
          Unit = "${name}.service";
        };
      };

      systemd.services.${name} = {
        path = with pkgs; [
          gitMinimal
          openssh
        ];
        script = ''
          set -euo pipefail

          systemctl show '*' --state=failed --property=Id --value --no-pager | while read -r unit; do
            journalctl -u "$unit" -n 15 | "${lib.getExe self'.packages.notify-me}" -t "systemd $unit failed"
          done
        '';
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          User = config.my.mainUser.name;
        };
      };
    };
}
