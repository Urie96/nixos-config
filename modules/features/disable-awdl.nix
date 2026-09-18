{
  flake.darwinModules.disable-awdl = { pkgs, lib, ... }: {
    launchd.daemons.disable-awdl = {
      serviceConfig.RunAtLoad = true;
      command =
        let
          disable-awdl = pkgs.writeShellApplication {
            name = "disable-awdl";
            runtimeInputs = with pkgs; [
              coreutils
              gnugrep
            ];
            text = ''
              while true; do
                  if ifconfig awdl0 |grep -q "<UP"; then
                      (set -x; ifconfig awdl0 down)
                  fi

                  sleep 1
              done
            '';
          };
        in
        lib.getExe disable-awdl;
    };
  };
}
