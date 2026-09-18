{
  flake.nixosModules.special-day-notify =
    { pkgs, ... }:
    let
      name = "special-day-notify";
      pkg = pkgs.python3Packages.buildPythonApplication rec {
        pname = "special-day-notify";
        version = "0.0.1";
        pyproject = false;

        src = ./.;

        dependencies = with pkgs.python3Packages; [
          lunarcalendar
        ];

        installPhase = ''
          install -Dm755 "./main.py" "$out/bin/${pname}"
        '';
      };
    in
    {
      systemd.timers.${name} = {
        wantedBy = [ "timers.target" ];
        after = [ "network.target" ];
        timerConfig = {
          OnCalendar = "09:00:00"; # systemd-analyze calendar --iterations 10 "Mon,Tue *-*-01..04 12:00:00"
          Unit = "${name}.service";
          RandomizedDelaySec = 3600;
          Persistent = true;
        };
      };

      systemd.services.${name} = {
        path = with pkgs; [
          gitMinimal
          openssh
        ];
        script = "${pkg}/bin/special-day-notify";
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
        };
      };
    };
}
