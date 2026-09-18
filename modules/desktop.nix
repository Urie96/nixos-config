{ self, ... }:
{
  flake.nixosModules.desktop =
    {
      pkgs,
      inputs',
      self',
      ...
    }:
    {
      imports = [
        self.inputs.srvos.nixosModules.desktop
      ]
      ++ (with self.nixosModules; [
        hyprland
        font
        keyd
        rime
        # niri
      ]);

      environment.systemPackages = with pkgs; [
        wl-clipboard # 剪切板
        cliphist # 剪切板历史
        wtype # 模拟键盘输入text

        noctalia-shell # Desktop shell (bar, notifications, control center, OSD)

        grim # 截图
        slurp # 截图选区

        self'.packages.kitty
        chromium
        ferdium
        inputs'.zen-browser.packages.default
        mpv

        pciutils
        usbutils
        iw
        ethtool
      ];

      # Needed so xdg-open works properly with Nix-installed apps
      environment.sessionVariables = {
        # Enable native Wayland support for Electron apps (Ferdium, etc.) and Chromium
        NIXOS_OZONE_WL = "1";
      };

      # 插入 U 盘 / 移动硬盘时自动挂载（udiskie 监听 udisks2 事件并自动挂载到 /run/media/<user>/）
      services.udisks2.enable = true;

      systemd.user.services.udiskie = {
        description = "Auto-mount removable drives on insertion";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.udiskie}/bin/udiskie";
          Restart = "on-failure";
          RestartSec = "3";
        };
      };
    };
}
