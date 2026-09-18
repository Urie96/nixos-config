{
  flake.nixosModules.wyoming =
    { ... }:
    {
      services.wyoming = {
        faster-whisper.servers.whisper = {
          enable = false;
          device = "cpu";
          # model = "tiny-int8";
          model = "medium";
          language = "zh";
          uri = "tcp://0.0.0.0:10300";
        };
        piper.servers.piper = {
          enable = true;
          voice = "zh_CN-huayan-medium";
          uri = "tcp://0.0.0.0:10200";
        };
      };
    };
}
