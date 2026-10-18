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
        meta.description = "启动 Android 34（arm64-v8a, google_apis）模拟器";
        program = "${lib.getExe (
          pkgs.androidenv.emulateApp {
            name = "emulate-MyAndroidApp";
            platformVersion = "34";
            abiVersion = "arm64-v8a"; # armeabi-v7a, mips, x86_64
            systemImageType = "google_apis";
          }
        )}";
      };
    };
}
