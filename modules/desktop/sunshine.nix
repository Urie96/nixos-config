{
  flake.nixosModules.sunshine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      hyprctl = lib.getExe' config.programs.hyprland.package "hyprctl";

      # Sunshine 只在启动时探测一次显示器和编码器；探测失败就一直拒绝串流
      # （Moonlight 报 503 "failed to initialize video capture/encoding. Is a display
      # connected and turned on?"），必须重启服务才会重新探测。
      #
      # 而 nixos-desktop 没接物理显示器时，headless 输出是由 Hyprland 起来之后
      # （modules/home/dotConfig/hypr/hyprland.lua 里的 exec-once）才创建的。两条启动
      # 路径存在竞态：开机时 sunshine 常常先跑起来、探到 0 个 wl_output 就卡死。
      # 所以这里让它等到至少有一个输出再真正启动。
      waitForOutput = pkgs.writeShellScript "sunshine-wait-for-output" ''
        for _ in $(seq 1 60); do
          out=$(${hyprctl} monitors -j 2>/dev/null || true)
          if [ -n "$out" ] && [ "$out" != "[]" ]; then
            exit 0
          fi
          sleep 0.5
        done
        # 等不到也照常启动，让 web UI 可用，避免卡在 start-limit 里
        exit 0
      '';

      # Sunshine 的 CSRF 校验只放行写死的 https://localhost、https://127.0.0.1、
      # https://[::1]（见 src/config.cpp），用 LAN IP 打开 web UI 时提交表单会报
      # "CSRF Protection Error"。这里把实际会用到的地址补进白名单。
      # 192.168.2.5 见 modules/machines/nixos-desktop.nix 的 deploy.targetHost。
      origins = [
        "https://192.168.2.5"
        "https://${config.networking.hostName}"
        "https://${config.networking.hostName}.local" # avahi/mDNS
      ];
    in
    {
      # Sunshine：Moonlight 客户端（macOS / 手机 / 电视盒子）远程控制本机的 Hyprland
      # 会话。选它而不是 wayvnc 的原因：
      #   - AMD iGPU 走 VAAPI 硬件编码（HEVC/H.264），4K 桌面滚动/视频也顺；
      #   - 带音频（Opus）；
      #   - 输入通过 uinput 注入，对客户端来说就是真实键盘鼠标，锁屏、全屏游戏都吃得下。
      #
      # nixos-desktop 上 `networking.firewall.enable = false`，端口不用额外开。
      # web UI 是 HTTPS，端口是 `port + 1` 即 47990（47984/47989 是串流端口，不是 http）：
      #   https://192.168.2.5:47990（自签证书，浏览器要手动放行）
      # 首次连接：Moonlight 上会显示 PIN，然后在 web UI 的 PIN 页面输入。
      #
      # 依赖图形会话里至少有一个 wl_output：nixos-desktop 现在没接显示器，
      # 由 modules/home/dotConfig/hypr/hyprland.lua 在启动时自动建 headless 输出。
      services.sunshine = {
        enable = true;

        # 走 wlr-screencopy 抓屏（Hyprland 实现了 zwlr_screencopy_manager_v1），
        # 因此不需要 capSysAdmin（那是 KMS 抓屏才要的 root 能力）。
        # 注意：一旦设置 settings，Sunshine 就以这个配置文件为准，web UI 里改的配置不再保存。
        settings = {
          capture = "wlr";
          csrf_allowed_origins = lib.concatStringsSep "," origins;
          # 单显示器时留空，由 Sunshine 自动选输出；接多台显示器后再取消注释，填
          # `hyprctl monitors` 里输出的连接器名（如 DP-1 / HDMI-A-1）。
          # output_name = "DP-1";
        };
      };

      systemd.user.services.sunshine.serviceConfig.ExecStartPre = "${waitForOutput}";

      # 显示器 DPMS 休眠后抓屏可能是黑的，从远端连上后如果想立刻恢复：
      #   hyprctl dispatch dpms on
      # 另外 greetd 没起 uwsm/Hyprland 之前没有图形会话可抓（抓到的是空）。
    };
}
