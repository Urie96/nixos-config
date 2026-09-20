{
  flake.nixosModules.apple-music-api =
    {
      lib,
      inputs',
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
      port = 8899;
    in
    {
      systemd.services.apple-music-api = {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Restart = "always";
          DynamicUser = true;
          StateDirectory = "apple-music-api";
          ExecStart = "${lib.getExe nur.apple-music-api} -port ${toString port} -config-dir /var/lib/apple-music-api";
        };
      };
    };
}
