{
  flake.nixosModules.hyprland =
    {
      config,
      pkgs,
      ...
    }:
    {
      programs.hyprland = {
        enable = true;
        # UWSM 启动：自动管理 systemd user targets（graphical-session.target 等），推荐方式
        withUWSM = true;
        # XWayland 默认开启，Steam 等 X11 应用依赖它
        xwayland.enable = true;
      };

      # Hyprland 生态常用工具
      environment.systemPackages = with pkgs; [
        hyprpaper # 壁纸
        hyprlock # 锁屏
        hypridle # 空闲管理（自动锁屏/挂起）
        hyprpicker # 屏幕取色
        hyprshot # 截图
        hyprpolkitagent # polkit 认证弹窗
        hyprsunset # 夜间护眼
      ];

      # greetd auto-starts Hyprland (via UWSM), noctalia-shell 的锁屏负责登录界面
      # 注意: 必须用 "hyprland.desktop"（带 .desktop 后缀）而不是 "hyprland":
      #   - uwsm 才能解析到 desktop entry，从而正确设置 XDG_CURRENT_DESKTOP=Hyprland（否则变成 hyprland:Hyprland 触发警告）
      #   - entry 的 Exec 是 start-hyprland wrapper，会建立 watchdog（直接跑 hyprland 二进制会触发
      #     "启动时未使用 start-hyprland" 警告）
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.uwsm}/bin/uwsm start hyprland.desktop";
            user = "urie";
          };
        };
      };

      # programs.kdeconnect.enable = true;

      services.gnome.gnome-keyring.enable = true;
    };
}
