{
  flake.nixosModules.jellyfin-server =
    { pkgs, ... }:
    {
      hardware.graphics.enable = true;
      environment.systemPackages = with pkgs; [
        libva
        libva-utils # 通过vainfo命令校验是否配置成功
      ];

      services.jellyfin = {
        enable = true;
        hardwareAcceleration = {
          enable = true;
          device = "/dev/dri/renderD128";
          type = "vaapi";
        };

        transcoding = {
          enableHardwareEncoding = true;
          hardwareDecodingCodecs = {
            h264 = true; # 必备，常见格式
            hevc = true; # 必备，1080p/4K 常用
            hevc10bit = false; # 780M 支持，但你需要的话开启
            vp9 = true; # YouTube/WebM 常用
            av1 = true; # 新型格式，780M 支持
            mpeg2 = false; # 老格式，几乎不用
            vc1 = false; # 老格式，几乎不用
            vp8 = true; # WebM 兼容
          };

          hardwareEncodingCodecs = {
            hevc = true; # 推荐，开启能降低 CPU 占用
            av1 = false; # ❌ 780M 不支持 AV1 编码
          };
        };

        forceEncodingConfig = true;
      };

      services.nginx.virtualHosts."jellyfin.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          proxyWebsockets = true;
        };
      };
    };
}
