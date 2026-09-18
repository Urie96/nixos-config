{
  flake.droidModules.audio =
    { pkgs, ... }:

    {
      runit.services.pulseaudio = {
        enable = true;
        execute.run = pkgs.writeScriptBin "pulseaudio-run" ''
          #!${pkgs.runtimeShell}

          # Ensure a fresh start every time: if a pid file exists, kill the
          # recorded process (failures ignored) and remove the file. Otherwise
          # a stale pid file (previous instance killed without cleanup) makes
          # pulseaudio refuse to start.

          runtime_dir="''${PULSE_RUNTIME_PATH:-/tmp/pulse-run}"
          pid_file="$runtime_dir/pid"

          if [ -f "$pid_file" ]; then
            old_pid="$(${pkgs.coreutils}/bin/tr -d '[:space:]' < "$pid_file" 2>/dev/null || true)"
            if [ -n "$old_pid" ]; then
              kill "$old_pid" 2>/dev/null || true
            fi
            rm -f "$pid_file"
          fi

          exec /data/data/com.termux.nix/files/home/.local/state/nix/profile/bin/pulseaudio --daemonize=no
        '';
      };

      build.activationAfter.installPulseaudio =
        let
          pulseaudioNarGz = pkgs.fetchurl {
            url = "https://github.com/Urie96/nixdroidpkgs/releases/download/v0.0.1/prebuilt.nar.gz";
            sha256 = "1qla663ghgnikpyp99ps89mlnxb3lkw7lw26cr77afpzakpsslk6";
          };
        in
        ''
          imported="$(${pkgs.gzip}/bin/gunzip -c "${pulseaudioNarGz}" | $DRY_RUN_CMD nix-store --import 2>/dev/null)"

          pulse_path="$(printf '%s\n' "$imported" | grep -E '/nix/store/.*-pulseaudio-android-' | head -n1)"
          test -n "$pulse_path"

          $DRY_RUN_CMD nix profile remove pulseaudio-android-aarch64-unknown-linux-android || true
          $DRY_RUN_CMD nix profile add "$pulse_path"
        '';

      environment.sessionVariables = {
        PULSE_SERVER = "unix:/tmp/pulse-run/native";
      };

      environment.etc."mpv/mpv.conf".text = ''
        ao=pulse
        # Disable Video Decode and Output
        vid=no
      '';

      environment.packages = with pkgs; [
        mpv
      ];
    };
}
