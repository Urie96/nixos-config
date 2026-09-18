{
  flake.nixosModules.netease-cloud-music-api =
    {
      inputs',
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
    in
    {
      systemd.services.netease-cloud-music-api = {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          PORT = "3110";
        };
        serviceConfig = {
          Restart = "always";
          DynamicUser = true;
          ExecStart = "${nur.NeteaseCloudMusicApi}/bin/NeteaseCloudMusicApi";
        };
      };
    };
}
