{
  flake.nixosModules.xiaozhi-server-rs =
    {
      config,
      inputs',
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
    in
    {
      clan.core.vars.generators.xiaozhi-server-rs = {
        files.env-file = { };
        prompts.volcengine-api-key = { };
        script = ''
          echo "VOLCENGINE_API_KEY=$(cat $prompts/volcengine-api-key)" >>"$out/env-file"
        '';
      };

      systemd.services.xiaozhi-server-rs = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig = {
          Description = "xiaozhi-server-rs service";
        };
        serviceConfig = {
          ExecStart = "${nur.xiaozhi-server-rs}/bin/xiaozhi-server-rs";
          WorkingDirectory = "/var/lib/xiaozhi-server-rs";
          StateDirectory = "xiaozhi-server-rs";
          Restart = "on-failure";
          RestartSec = "5s";
          Environment = [
            "XIAOZHI_BIND=0.0.0.0:3116"
            "XIAOZHI_PUBLIC_WS_URL=ws://home.lubui.com:3116/ws"
            "XIAOZHI_TTS_PROVIDER=volcengine"
            "VOLCENGINE_TTS_VOICE_TYPE=zh_female_wanwanxiaohe_moon_bigtts"
            "VOLCENGINE_TTS_VOICE_TYPE=zh_female_vv_uranus_bigtts"
            "VOLCENGINE_TTS_ENCODING=ogg_opus"
            "XIAOZHI_ASR_PROVIDER=volcengine"
            "VOLCENGINE_ASR_RESOURCE_ID=volc.seedasr.sauc.duration"
            "XIAOZHI_LLM_PROVIDER=pi"
            "XIAOZHI_PI_HTTP_BASE_URL=http://127.0.0.1:3115"
            "XIAOZHI_SPEAKER_PROVIDER=speaker_id"
            "XIAOZHI_SPEAKER_DB_DIR=/var/lib/xiaozhi-server-rs/speakers"
          ];
          EnvironmentFile = config.clan.core.vars.generators.xiaozhi-server-rs.files.env-file.path;
        };
      };
    };
}
