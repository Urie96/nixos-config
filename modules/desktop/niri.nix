{
  flake.nixosModules.niri =
    {
      config,
      pkgs,
      ...
    }:
    {
      programs.niri.enable = true;

      # niri 26.x 通过 xwayland-satellite 提供 X11 兼容层（Steam 等 X11 应用依赖它）。
      # niri 启动时会从 PATH 中查找 xwayland-satellite；nixpkgs 的该包自带 Xwayland。
      environment.systemPackages = [ pkgs.xwayland-satellite ];

      # greetd auto-starts niri, noctalia-shell's lock screen handles login
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${config.programs.niri.package}/bin/niri-session";
            user = "urie";
          };
        };
      };

      # programs.kdeconnect.enable = true;

      services.gnome.gnome-keyring.enable = true;
    };
}
