{
  flake.nixosModules.rime =
    { pkgs, ... }:
    {
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5.waylandFrontend = true;
        fcitx5.addons = with pkgs; [
          fcitx5-fluent # 主题皮肤
          (fcitx5-rime.override {
            rimeDataPkgs = [
              pkgs.rime-ice
            ];
          })
        ];

        # 写到 /etc/xdg/fcitx5/conf/classicui.conf (经典用户界面)
        fcitx5.settings.addons.classicui = {
          globalSection = {
            # Theme = "FluentDark"; # 启用已安装的 fcitx5-fluent 主题
            Font = "Noto Sans CJK SC 14"; # 候选词字号(默认 Sans 10 偏小)
          };
        };
      };
    };

  flake.darwinModules.rime =
    {
      pkgs,
      lib,
      self,
      ...
    }:
    {
      launchd.user.agents.sync-rime = {
        serviceConfig = {
          StartCalendarInterval = [
            {
              Minute = 0;
            }
          ];
          ProgramArguments =
            let
              sync-rime = pkgs.writeShellApplication {
                name = "sync-rime";
                runtimeInputs = with pkgs; [
                  coreutils
                  rsync
                  yq-go
                ];
                text = ''
                  config_path="$HOME/Library/Rime"
                  install_id="$(yq .installation_id "$config_path/installation.yaml")"
                  rsync -az --mkpath urie@home.lubui.com:~/rime/rime_ice.userdb.txt "$config_path/sync/$install_id/rime_ice.userdb.txt"
                  sleep $((RANDOM % 20))
                  /Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --sync
                  sleep $((RANDOM % 20))
                  rsync -auEzhv --mkpath --progress "$config_path/sync/$install_id/rime_ice.userdb.txt" urie@home.lubui.com:~/rime/rime_ice.userdb.txt
                '';
              };
            in
            [ (lib.getExe sync-rime) ];

          ThrottleInterval = 60;
          StandardOutPath = "/tmp/rime-sync.stdout.log";
          StandardErrorPath = "/tmp/rime-sync.stderr.log";
        };
      };
    };
}
