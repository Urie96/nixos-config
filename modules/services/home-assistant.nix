{
  flake.nixosModules.home-assistant =
    {
      config,
      pkgs,
      inputs',
      ...
    }:
    let
      customComponents = inputs'.nur-packages.legacyPackages.hassComponents.override {
        home-assistant = config.services.home-assistant.package;
      };
    in
    {
      services.home-assistant = {
        enable = true;
        # 直接继承pkg，因为module的extraComponents似乎没有自动安装python依赖
        package = pkgs.home-assistant.override (oldArgs: {
          extraComponents = oldArgs.extraComponents or [ ] ++ [
            "esphome"
            "tasmota"
            "mqtt"
            "mobile_app"
            "google_translate"
            "ffmpeg"
            "zeroconf"
            "homekit"
            # "whisper"
            "piper"
            "mcp_server"
            "open_router"
            "matter"
            "wled"
            "music_assistant"
            "history"
          ];
          extraPackages =
            ps: with ps; [
              pyatv
              aiohomekit
              python-otbr-api
              wyoming
            ];
        });
        customComponents = with customComponents; [
          sonoff_lan
          volc_tts
        ];
        config = {
          "automation ui" = "!include automations.yaml";
          "scene ui" = "!include scenes.yaml";
          "script ui" = "!include scripts.yaml";
          homeassistant = {
            name = "Urie Home";
            latitude = "39.9";
            longitude = "116.32";
          };
          # nginx反向代理需要
          http = {
            use_x_forwarded_for = true;
            trusted_proxies = [ "127.0.0.1" ];
          };
          mobile_app = { };
          mqtt = [ ];
          history = { };
          logbook = { };
        };
      };

      services.nginx.virtualHosts."hass.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:8123";
          proxyWebsockets = true;
        };
      };
    };
}
