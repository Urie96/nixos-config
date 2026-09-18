{
  perSystem =
    {
      pkgs,
      lib,
      system,
      self',
      inputs',
      ...
    }:
    {
      apps.android-emulator = {
        type = "app";
        program = "${lib.getExe pkgs.androidenv.emulateApp {
          name = "emulate-MyAndroidApp";
          platformVersion = "34";
          abiVersion = "arm64-v8a"; # armeabi-v7a, mips, x86_64
          systemImageType = "google_apis";
        }}";
      };
    };
}
