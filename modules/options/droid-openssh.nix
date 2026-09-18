{
  flake.droidModules.common =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.openssh;

      inherit (lib)
        concatMapStrings
        concatStringsSep
        mkEnableOption
        mkIf
        mkOption
        types
        ;
    in
    {
      options.services.openssh = {
        enable = mkEnableOption "the OpenSSH daemon (sshd) as a runit service";

        ports = mkOption {
          type = types.listOf types.int;
          default = [ 8022 ];
          description = "TCP ports sshd listens on.";
        };

        authorizedKeys = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "ssh-ed25519 AAAA... user@host" ];
          description = ''
            SSH public keys authorized for the nix-on-droid user. Written to
            `/etc/ssh/authorized_keys.d/${config.user.userName}`, which
            `AuthorizedKeysFile` includes via the `%u` expansion.
          '';
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = "Extra lines appended to sshd_config.";
        };
      };

      config = mkIf cfg.enable {
        environment.etc."/ssh/sshd_config".text = ''
          ${concatMapStrings (port: "Port ${toString port}\n") cfg.ports}
          AuthorizedKeysFile %h/.ssh/authorized_keys /etc/ssh/authorized_keys.d/%u

          PubkeyAuthentication yes
          PasswordAuthentication no
          StrictModes no

          Subsystem sftp ${pkgs.openssh}/libexec/sftp-server -e
          ${cfg.extraConfig}
        '';

        environment.etc."ssh/authorized_keys.d/${config.user.userName}".text =
          concatStringsSep "\n" cfg.authorizedKeys;

        # Host key: generate once at switch time if missing (activationBefore
        # guarantees this runs before runsvdir is started). The runit run
        # script below no longer checks or regenerates it.
        build.activationBefore.sshdHostKeys = ''
          if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
            $DRY_RUN_CMD mkdir --parents /etc/ssh
            $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
          fi
        '';

        # Fail loudly if runit isn't actually enabled (or the runit module
        # isn't imported at all), instead of silently defining a service that
        # nothing will ever supervise.
        assertions = [
          {
            assertion = config.runit.enable or false;
            message = ''
              `services.openssh` requires the runit module to be enabled.
              Set `runit.enable = true;` (and import the runit module).
            '';
          }
        ];

        # sshd in the foreground with -D -e so that runsv can track and
        # restart it; stdout/stderr feed the svlogd log service (the runit
        # module links the default ./log/run), which rotates into
        # ${svdir}/sshd/log/current.
        runit.services.sshd = {
          enable = true;
          execute.run = pkgs.writeScriptBin "service-sshd-run" ''
            #!${pkgs.runtimeShell}

            # Kill any existing sshd master daemon before starting a new one,
            # so the listening ports are free. This catches masters orphaned by
            # a previous runsvdir teardown; in a normal runsv restart the old
            # master is already gone. The pattern matches only the master
            # ("sshd -D -e -f ..."), NOT session processes ("sshd: user@pts/N"),
            # so established connections stay alive.
            master_pattern="sshd -D -e -f /etc/ssh/sshd_config"

            for pid in $(${pkgs.procps}/bin/pgrep -f "$master_pattern" 2>/dev/null || true); do
              kill "$pid" 2>/dev/null || true
            done

            # Wait (bounded) for the old master to release its sockets; force
            # kill if it ignores TERM.
            waited=0
            while ${pkgs.procps}/bin/pgrep -f "$master_pattern" > /dev/null 2>&1; do
              if [ "$waited" -ge 20 ]; then
                for pid in $(${pkgs.procps}/bin/pgrep -f "$master_pattern" 2>/dev/null || true); do
                  kill -KILL "$pid" 2>/dev/null || true
                done
                break
              fi
              ${pkgs.coreutils}/bin/sleep 1
              waited=$((waited + 1))
            done

            exec ${pkgs.openssh}/bin/sshd -D -e -f /etc/ssh/sshd_config
          '';
          svlogd = {
            enable = true;
            config = ''
              # Rotate at 1MB, keep 10 old logs, max age 12h
              s1000000
              n10
              N10
              t43200
            '';
          };
        };

        environment.packages = [
          pkgs.openssh
        ];
      };
    };
}
