{
  flake.droidModules.common =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (builtins)
        toString
        ;

      inherit (lib)
        attrByPath
        attrValues
        concatStringsSep
        filterAttrs
        getExe
        literalExpression
        mapAttrs
        mkEnableOption
        mkIf
        mkOption
        optionalString
        optionals
        typeOf
        ;

      inherit (lib.types)
        attrsOf
        int
        either
        nonEmptyStr
        nullOr
        package
        path
        submodule
        ;

      inherit (pkgs)
        makeWrapper
        runit
        writeTextFile
        ;

      inherit (pkgs.stdenv)
        mkDerivation
        ;

      mkService =
        { name, ... }:
        let
          control = mkOption {
            description = ''
              [man rusv -- Control](https://smarden.org/runit1/runsv.8#sect3)

              Services have a named pipe under `''${config.runit.settings.environment.svdir}/NAME/supervise/control`
              Logs have a named pipe under `''${config.runit.settings.environment.svdir}/NAME/log/supervise/control`

              These named pipes when written to with a given control character may call associated executable.
            '';

            example = literalExpression ''
              ## Service control
              runit.services.NAME.control.u = '''
                #!''${pkgs.runtimeShell}

                _exe_basename="''${pkgs.coreutils.outPath}/bin/basename";
                _exe_dirname="''${pkgs.coreutils.outPath}/bin/dirname";

                _name="$("$_exe_basename" "$("$_exe_dirname" "$PWD")")";

                echo "control/u called for: $_name";
              '''

              ## Log control
              runit.services.NAME.log.control.u = '''
                #!''${pkgs.runtimeShell}

                _exe_basename="''${pkgs.coreutils.outPath}/bin/basename";
                _exe_dirname="''${pkgs.coreutils.outPath}/bin/dirname";

                _parent="$("$_exe_basename" "$("$_exe_dirname" "$PWD")")";
                _name="$("$_exe_basename" "$_parent")";

                echo "control/u called for: $_name/log";
              '''
            '';

            default = { };
            type = submodule {
              options = {
                u = mkOption {
                  description = ''
                    Up. If the service is not running, start it. If the sesrvice stops, restart it.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                d = mkOption {
                  description = ''
                    Down. If the service is running, send it a TERM signal. If `./run` exits, start `./finish` if it exists. After it stops, do not restart service.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                o = mkOption {
                  description = ''
                    Once. If the service is not running, start it. Do not restart it if it stops.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                p = mkOption {
                  description = ''
                    Pause. If the service is running, send it a STOP signal.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                c = mkOption {
                  description = ''
                    Continue. If the service is running, send it a CONT signal.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                h = mkOption {
                  description = ''
                    Hangup. If the service is running, send it a HUP signal.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                a = mkOption {
                  description = ''
                    Alarm. If the service is running, send it a ALRM signal.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                i = mkOption {
                  description = ''
                    Interrupt. If the service is running, send it a INT signal.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                q = mkOption {
                  description = ''
                    Quit. If the service is running, send it a QUIT signal.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                "1" = mkOption {
                  description = ''
                    If the service is running, send it a USR1 signal.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                "2" = mkOption {
                  description = ''
                    If the service is running, send it a USR2 signal.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                k = mkOption {
                  description = ''
                    Kill. If the service is running, send it a KILL signal.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                x = mkOption {
                  description = ''
                    Exit. If the service is running, send it a TERM signal.

                    Aliase of `e`, check `e` for more documentation and examples.
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
                e = mkOption {
                  description = ''
                    Exit. If the service is running, send it a TERM signal.
                    Aliase of `x`

                    Do not restart the service. If the service is down, and no log service exists, `runsv` exits.

                    If the service is down and a log service exits, `runsv` closes the standard input of the log service, and waits for it to terminate.

                    If the log sservice is down, `runsv` exits.

                    This command is ignored if it is given to the `service/log/supervise/control`

                    Example: to send a TERM signal to the socklog-unix service, either do `runsvctrl term ''${runit.settings.environment.svdir}/socklog-unix`

                    or

                    `echo -n t >''${runit.settings.environment.svdir}/socklog-unix/supervise/control`
                  '';
                  type = nullOr nonEmptyStr;
                  default = null;
                };
              };
            };
          };
        in
        {
          options = {
            enable = mkEnableOption "Enable named service executables";

            svlogd = mkOption {
              description = ''
                See: https://smarden.org/runit/svlogd.8
              '';

              example = literalExpression ''
                See: https://smarden.org/runit/svlogd.8

                runit.services.NAME.svlogd = {
                  enable = true;
                  config = '''
                    # Max file size
                    s1000000
                    # Number of log files to keep
                    n10
                    # Minimum number of old log files to maintain, must be less than `n`
                    N10
                    # Max age in seconds of current log file before rotating
                    t41968
                    # ...
                  ''';
                };
              '';

              default = { };
              type = submodule {
                options = {
                  enable = mkEnableOption ''
                    svlogd logging for the named service: creates the `log` service
                    subdirectory with a default `./log/run` script (svlogd reading the
                    service's stdout/stderr with per-line timestamps) and links
                    `./log/config` when `config` is set. Override the log script with
                    `execute.log.run`. Without this, no log service is created and
                    the service's stdout/stderr is discarded.
                  '';

                  config = mkOption {
                    description = ''
                      May be multi-line string defining configurations, or path to preexisting configuration file

                      See: https://smarden.org/runit/svlogd.8#config
                    '';
                    default = null;
                    type = nullOr (either nonEmptyStr path);
                  };
                };
              };
            };

            execute = mkOption {
              description = ''
                Executables that may be called for starting, stopping, logging, and control signals of named service.
              '';

              type = submodule {
                options = {
                  inherit control;

                  run = mkOption {
                    description = "Script that `sv` will call for starting service";

                    example = literalExpression ''
                      runit.services.sshd.log = writeScriptBin "service-sshd-run" '''
                        #!''${pkgs.runtimeShell}

                        ''${pkgs.openssh}/bin/ssh-keygen -Af ''${config.build.installationDir}

                        mkdir -p ''${builtins.dirOf cfg.settings.PidFile}

                        exec ''${pkgs.openssh}/bin/sshd -f "''${config.environment.etc."ssh/sshd_config".source}" -De 2>&1
                      '''
                    '';

                    type = package;
                  };

                  check = mkOption {
                    description = ''
                      Executable `sv` will call to check service is in given up/down state

                      See: https://smarden.org/runit/sv.8#additional-commands
                    '';

                    example = literalExpression ''
                      runit.services.sshd.check = writeScriptBin "service-sshd-check" '''
                        #!''${pkgs.runtimeShell}

                        printf 'service-sshd-check called';
                        env;
                        printf '%s\n' "''${@}";
                      '''
                    '';

                    type = nullOr package;
                    default = null;
                  };

                  finish = mkOption {
                    description = "Script that `sv` will call for stopping service";

                    example = literalExpression ''
                      runit.services.sshd.log = writeScriptBin "service-sshd-finish" '''
                        #!''${pkgs.runtimeShell}

                        _exe_basename="''${pkgs.coreutils.outPath}/bin/basename";
                        _exe_dirname="''${pkgs.coreutils.outPath}/bin/dirname";

                        _name="$("$_exe_basename" "$("$_exe_dirname" "$PWD")")";

                        env;
                        echo "FINISED: _name -> $_name";
                      '''
                    '';

                    type = nullOr package;
                    default = null;
                  };

                  log = mkOption {
                    default = { };
                    type = submodule {
                      options = {
                        inherit control;

                        run = mkOption {
                          description = ''
                            Script that `sv` will call for logging service.

                            See: https://smarden.org/runit/svlogd.8
                          '';

                          example = literalExpression ''
                            runit.services.sshd.log.run = writeScriptBin "service-sshd-log-run" '''
                              #!''${pkgs.runtimeShell}

                              exec "''${config.runit.package.outPath}/bin/svlogd" -tt "''${config.runit.settings.environment.svdir}/__NAME__";
                            '''
                          '';

                          type = nullOr package;
                          default = null;
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };

      cfg = config.runit;

      ## Per-service directory materialization. Previously each service had its
      ## own `build.activation` script; now it is one combined script that
      ## `runsvdir-start` runs before starting the supervisor.
      service-setup =
        let
          per-service =
            if cfg.services != { } then
              mapAttrs (
                name: service:
                let
                  package-check = attrByPath [ "execute" "check" ] null service;
                  package-finish = attrByPath [ "execute" "finish" ] null service;
                  package-log-run = attrByPath [ "execute" "log" "run" ] null service;

                  ## Whether a log service should exist at all. Opt-in only:
                  ## without svlogd.enable (or an explicit execute.log.run) no
                  ## `log/` directory is created, so runsv never tries to run
                  ## a non-existent log service.
                  log-service-enabled = service.svlogd.enable || package-log-run != null;

                  ## Default log service script: svlogd with per-line timestamps,
                  ## writing to ${svdir}/NAME/log/current. runsv runs ./log/run
                  ## with cwd = the log directory, so svlogd gets "." as its
                  ## directory argument — without it svlogd only prints usage
                  ## and exits (svlogd requires at least one dir argument).
                  default-log-run = pkgs.writeScriptBin "service-${name}-log-run" ''
                    #!${pkgs.runtimeShell}
                    exec ${cfg.settings.packageWrapped}/bin/svlogd -tt .
                  '';

                  ## `control` values are declared as script text (`nonEmptyStr`,
                  ## see the `control` option), so materialize them as store
                  ## executables before symlinking them into the service dir.
                  controlMappedToLink =
                    { directory, control-config }:
                    mapAttrs (character: script: ''
                      $DRY_RUN_CMD ln $VERBOSE_ARG -sf "${
                        getExe (
                          if typeOf script == "string" then
                            pkgs.writeScriptBin "control-${name}-${character}" script
                          else
                            script
                        )
                      }" "${directory}/${character}";
                    '') (filterAttrs (_name: script: script != null) control-config);

                  control-service-links = controlMappedToLink {
                    directory = "${cfg.settings.environment.svdir}/${name}/control";
                    control-config = service.execute.control;
                  };

                  control-log-links = controlMappedToLink {
                    directory = "${cfg.settings.environment.svdir}/${name}/log/control";
                    control-config = service.execute.log.control;
                  };

                  svlogd-config = optionalString (service.svlogd.enable && service.svlogd.config != null) (
                    if (typeOf service.svlogd.config) == "path" then
                      ''
                        $DRY_RUN_CMD ln $VERBOSE_ARG -sf "${service.svlogd.config}" "${cfg.settings.environment.svdir}/${name}/log/config";
                      ''
                    else if (typeOf service.svlogd.config) == "string" then
                      ''
                        $DRY_RUN_CMD ln $VERBOSE_ARG -sf "${
                          (writeTextFile {
                            name = "svlogd-${name}";
                            text = service.svlogd.config;
                          }).outPath
                        }" "${cfg.settings.environment.svdir}/${name}/log/config";
                      ''
                    else
                      throw "`runit.services.${name}.svlogd.config` is neither `string` or `path` type"
                  );
                in
                ''
                  ## pid and lock files expected to live here
                  $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${cfg.settings.environment.svdir}/${name}/supervise";

                  ## `./run` executable expected to be here for starting
                  $DRY_RUN_CMD ln $VERBOSE_ARG -sf "${getExe service.execute.run}" "${cfg.settings.environment.svdir}/${name}/run";
                ''
                + optionalString (package-check != null) ''
                  ## `./check` executable expected to be to modify how `sv` checks for service states
                  $DRY_RUN_CMD ln $VERBOSE_ARG -sf "${getExe package-check}" "${cfg.settings.environment.svdir}/${name}/check";
                ''
                + optionalString (package-finish != null) ''
                  ## `./finish` executable expected to be here when `${name}/run` exits
                  $DRY_RUN_CMD ln $VERBOSE_ARG -sf "${getExe package-finish}" "${cfg.settings.environment.svdir}/${name}/finish";
                ''
                + optionalString log-service-enabled ''
                  ## Log service (opt-in): only created when the service
                  ## explicitly enables logging, so runsv never tries to
                  ## start a non-existent ./log/run for the others.
                  $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${cfg.settings.environment.logdir}/${name}";
                  $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${cfg.settings.environment.svdir}/${name}/log";
                  $DRY_RUN_CMD ln $VERBOSE_ARG -sf "${
                    getExe (if package-log-run != null then package-log-run else default-log-run)
                  }" "${cfg.settings.environment.svdir}/${name}/log/run";
                ''
                + optionalString (service.execute.control != { }) ''
                  $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${cfg.settings.environment.svdir}/${name}/control";
                  ${concatStringsSep "\n" (attrValues control-service-links)}
                ''
                + optionalString (service.execute.log.control != { } && log-service-enabled) ''
                  $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${cfg.settings.environment.svdir}/${name}/log/control";
                  ${concatStringsSep "\n" (attrValues control-log-links)}
                ''
                + svlogd-config
              ) (filterAttrs (_name: service: service.enable) cfg.services)
            else
              { };
        in
        concatStringsSep "\n" (attrValues per-service);

      ## Shared helper for runsvdir-start / runsvdir-stop: reap svlogd daemons
      ## that log into this module's directories but no longer have a live
      ## supervisor. svlogd takes an exclusive lock on its log directory, so
      ## a leftover instance makes the next svlogd — runsvdir's own logger or
      ## a service's log/run — die with "unable to lock directory" and
      ## runsvdir's stderr pipe is left without a reader. That is the actual
      ## mechanism behind the symptoms "runsvdir-stop did nothing" (orphan
      ## svlogd kept running, ppid 1) and "runsvdir-start didn't come back"
      ## (new svlogd could not lock, pipeline died).
      ##
      ##   reap_stale_svlogd all       reap every svlogd under $svdir/$logdir
      ##                               (call when no runsvdir is running)
      ##   reap_stale_svlogd services  reap only service-log svlogd whose
      ##                               parent runsv is gone (ppid 1), keeping
      ##                               runsvdir's own logger (call when
      ##                               runsvdir is running)
      reapStaleSvlogd = ''
        reap_stale_svlogd() {
          # Dry-run activation: never kill processes.
          [ -n "$DRY_RUN_CMD" ] && return 0
          for pid in $(${pkgs.procps}/bin/pgrep -f svlogd 2>/dev/null || true); do
            # Never reap ourselves (matters when this script is inlined via
            # `bash -c`, which puts the whole body into our cmdline).
            [ "$pid" = "$$" ] && continue
            [ "$pid" = "$PPID" ] && continue
            cmdline="$(${pkgs.coreutils}/bin/tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
            cwd="$(${pkgs.coreutils}/bin/readlink "/proc/$pid/cwd" 2>/dev/null || true)"
            ppid="$(${pkgs.procps}/bin/ps -o ppid= -p "$pid" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' ' || true)"
            case "$1:$cmdline $cwd" in
              all:*"$svdir/"*|all:*"$logdir/"*) reap=1 ;;
              services:*"$svdir/"*) [ "$ppid" = "1" ] && reap=1 ;;
              *) reap=0 ;;
            esac
            if [ "$reap" = "1" ]; then
              kill "$pid" 2>/dev/null && echo "runsvdir: reaped orphaned svlogd ($pid)" >&2 || true
            fi
          done
        }
      '';

      runsvdir-start = pkgs.writeScriptBin "runsvdir-start" ''
        #!${pkgs.runtimeShell}

        svdir="${cfg.settings.environment.svdir}"
        logdir="${cfg.settings.environment.logdir}"

        # nix-on-droid's activation injects $DRY_RUN_CMD / $VERBOSE_ARG;
        # default to no-ops when this runs from a login hook instead.
        : "''${DRY_RUN_CMD:=}" "''${VERBOSE_ARG:=}"

        ## Materialize service directories (was: one build.activation script per
        ## service). Idempotent — mkdir -p + ln -sf refresh store symlinks.
        ${service-setup}

        # Nothing to supervise (services are only linked there when defined)
        if [ ! -d "$svdir" ]; then
          exit 0
        fi

        if ! ${pkgs.procps}/bin/pgrep -f "runsvdir.*$svdir" > /dev/null 2>&1; then
          mkdir --parents "$logdir/runsvdir"

          # Retire the legacy unbounded append log (keep one copy), then route
          # runsvdir's stderr through svlogd (config below: rotate at 1 MiB,
          # keep 5 rotated files) instead of appending to a single unbounded
          # file. A huge log here usually means a service is spewing restart
          # errors to runsvdir's stderr — svlogd's -tt timestamps make the
          # culprit easy to spot.
          if [ -f "$logdir/runsvdir.log" ]; then
            mv -f "$logdir/runsvdir.log" "$logdir/runsvdir.log.old" 2>/dev/null || true
          fi
          printf 's1048576\nn5\n' > "$logdir/runsvdir/config"

          ## No supervisor is running, so any svlogd still writing into our
          ## log dirs is a leftover from a dead runsvdir and holds its log
          ## directory locked. Reap before starting, or the fresh svlogd dies
          ## with "fatal: unable to lock directory" and runsvdir is left
          ## without its stderr sink.
          ${reapStaleSvlogd}
          reap_stale_svlogd all

          ## Start the supervisor in its own session (setsid), detached from
          ## any terminal. The old way — backgrounding from the login shell —
          ## left runsvdir/runsv/services in the shell's process group, so a
          ## logout pty hangup SIGHUPed the whole tree mid-shutdown: runsvdir
          ## relayed TERM to runsv and exited at once, and a runsv killed
          ## mid-down left its service running unsupervised (orphaned sshd).
          ## With setsid the tree has no controlling tty and pty hangups can
          ## not reach it; runsvdir-stop still works via explicit kill -HUP.
          ${pkgs.util-linux}/bin/setsid --fork ${cfg.settings.packageWrapped}/bin/runsvdir "$svdir" 2>&1 | \
            ${pkgs.util-linux}/bin/setsid --fork ${cfg.settings.packageWrapped}/bin/svlogd -tt "$logdir/runsvdir" &
        else
          ## runsvdir is up. Its own logger (ppid 1 by design) must stay, but
          ## a service's log svlogd whose runsv is gone (ppid 1) is stale and
          ## would keep that log directory locked, wedging the log service
          ## into a restart loop.
          ${reapStaleSvlogd}
          reap_stale_svlogd services
        fi
      '';

      # Stop runsvdir and every supervised service, WAITING for the shutdown
      # to complete.
      #
      # runsvdir on SIGHUP relays TERM to its runsv children and exits
      # immediately without waiting; each runsv then downs its service (TERM,
      # then KILL after the timeout) and exits. This background cascade races
      # against session teardown (e.g. fish exiting -> pty hangup -> SIGHUP to
      # the foreground process group, which contains runsvdir/runsv/services):
      # a runsv killed mid-down leaves its service running unsupervised (seen
      # with sshd surviving a Ctrl+D logout while pulseaudio died). So we wait
      # here until every supervisor is gone, with a bounded KILL fallback.
      runsvdir-stop = pkgs.writeScriptBin "runsvdir-stop" ''
        #!${pkgs.runtimeShell}

        svdir="${cfg.settings.environment.svdir}"
        logdir="${cfg.settings.environment.logdir}"
        # runsv children show up as "runsv <service>"; the trailing space
        # keeps the pattern from matching runsvdir itself ("runsvdir ...").
        runsvpattern="runsv "

        for pid in $(${pkgs.procps}/bin/pgrep -f "runsvdir.*$svdir" 2>/dev/null || true); do
          kill -HUP "$pid" 2>/dev/null || true
        done

        waited=0
        while :; do
          if ! ${pkgs.procps}/bin/pgrep -f "runsvdir.*$svdir" > /dev/null 2>&1 \
            && ! ${pkgs.procps}/bin/pgrep -f "$runsvpattern" > /dev/null 2>&1; then
            break
          fi
          if [ "$waited" -ge 20 ]; then
            # Last resort: force-kill whatever still supervises (a service
            # orphaned here is the lesser evil vs. hanging the shell exit).
            for pid in $(${pkgs.procps}/bin/pgrep -f "runsvdir.*$svdir" 2>/dev/null || true); do
              kill -KILL "$pid" 2>/dev/null || true
            done
            for pid in $(${pkgs.procps}/bin/pgrep -f "$runsvpattern" 2>/dev/null || true); do
              kill -KILL "$pid" 2>/dev/null || true
            done
            break
          fi
          sleep 1
          waited=$((waited + 1))
        done

        ## Supervisors are gone (cleanly or via the KILL fallback). Reap any
        ## svlogd left writing into our log dirs: they are ppid-1 orphans that
        ## hold their log-directory locks, blocking the next runsvdir-start.
        ## Until reaped they show up as exactly the kind of leftover process
        ## that made this command look broken ("no output, services running").
        ${reapStaleSvlogd}
        reap_stale_svlogd all
      '';
    in
    {
      options.runit = {
        enable = mkEnableOption "Enable runit configuration management";

        package = mkOption {
          description = ''
            Package that will be used with module and modified to include `config.runit.settings.environment.svdir`
          '';

          example = literalExpression ''
            package = pkgs.runit.overrideAttrs (oldAttrs: { ... });
          '';

          default = runit;
          type = package;
        };

        settings = mkOption {
          description = "";

          example = literalExpression ''
            runit.settings = {
              environment = {
                svdir = "''${config.build.installationDir}/var/service";
                logdir = "''${config.build.installationDir}/var/log";
                svwait = 7;
              };
            };
          '';

          default = { };
          type = submodule {
            options = {
              environment = mkOption {
                description = ''
                  Environment variables that will be set via `wrapProgram` on all `''${config.package.outPath}/bin` executables
                '';

                default = { };
                type = submodule {
                  options = {
                    svdir = mkOption {
                      description = ''
                        Where files in `config.runit.service.NAME` will be linked to for `runit`
                      '';
                      type = nonEmptyStr;
                      default = "${config.build.installationDir}/var/service";
                    };

                    logdir = mkOption {
                      description = ''
                        Where logs in `config.runit.service.NAME` will be read/written for `runit`

                        TODO: double-check this is correct!
                      '';
                      type = nonEmptyStr;
                      default = "${config.build.installationDir}/var/log";
                    };

                    svwait = mkOption {
                      description = ''
                        See: https://manpages.debian.org/unstable/runit/sv.8.en.html#SVWAIT
                      '';
                      type = nullOr int;
                      default = null;
                    };
                  };
                };
              };

              ## TODO: Find less hacky way of avoiding rebuild from source
              packageWrapped = mkOption {
                description = ''
                  Internal hacky mkDerivation modification used to avoid re-building `runit.package` from source
                '';

                example = literalExpression ''
                  package = pkgs.runit.overrideAttrs (oldAttrs: { ... });
                '';

                default = mkDerivation {
                  inherit (cfg.package) src;
                  name = "NoD-wrapped-${cfg.package.pname}";
                  version = "${cfg.package.version}-NoD-wrapped";
                  nativeBuildInputs = [ makeWrapper ];
                  installPhase =
                    let
                      environment-setters = concatStringsSep " " (
                        [
                          "--set SVDIR '${cfg.settings.environment.svdir}'"
                          "--set LOGDIR '${cfg.settings.environment.logdir}'"
                        ]
                        ++ (optionals (cfg.settings.environment.svwait != null) [
                          "--set SVWAIT '${toString cfg.settings.environment.svwait}'"
                        ])
                      );
                    in
                    ''
                      mkdir -p $out/bin;

                      while read -rd "" _executable; do
                        ln -sfv "$_executable" "$out/bin/";

                        wrapProgram "$out/bin/''${_executable##*/}" ${environment-setters};
                      done < <("${pkgs.lib.getExe pkgs.findutils}" "${cfg.package.outPath}/bin" -maxdepth 1 -type f -executable -print0)
                    '';
                };
                type = package;
              };
            };
          };
        };

        services = mkOption {
          description = "";

          example = literalExpression ''
            services.sshd = {
              name = "sshd";
              run-up = '''
                #!''${pkgs.runtimeShell}
                exec ''${pkgs.openssh}/bin/sshd -f "''${config.environment.etc."ssh/sshd_config".outPatn}" -De 2>&1
              ''';
            };
          '';

          type = attrsOf (submodule mkService);
        };
      };

      config = mkIf cfg.enable {
        environment.packages = [
          cfg.settings.packageWrapped
          runsvdir-start
          runsvdir-stop
        ];

        ## This does not seem to work, not without further investigation/fiddling
        # environment.sessionVariables = {
        #   SVDIR = cfg.settings.environment.svdir;
        # };

        ## nix-community/nix-on-droid -> modules/build/activation.nix
        ## Single activation step: `runsvdir-start` both materializes the
        ## service directories and starts the supervisor (see top of file).
        build.activation.runsvdir = ''
          $DRY_RUN_CMD ${runsvdir-start}/bin/runsvdir-start
        '';

        environment.loginHook = ''
          ${runsvdir-start}/bin/runsvdir-start
        '';
      };
    };
}
