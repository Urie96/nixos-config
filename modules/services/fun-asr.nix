{
  flake.nixosModules.fun-asr =
    {
      pkgs,
      lib,
      ...
    }:
    {
      systemd.services.fun-asr = {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Restart = "always";
          DynamicUser = true;
          ExecStart = "${lib.getExe pkgs.fun-asr-go} --addr 0.0.0.0 --port 3109";
        };
      };
    };
}
