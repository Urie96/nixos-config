let
  m =
    {
      pkgs,
      ...
    }:
    {
      wrappers.herdr.enable = true;
      wrappers.pi.settings.packages = [
        "${pkgs.herdr}/share/herdr/integrations/pi/herdr-agent-state.ts"
      ];
    };
in
{
  flake.wrappers.herdr =
    { ... }:
    {
      # 对应 ~/.config/herdr/config.toml 里去掉注释后仍然生效的部分。
      settings = {
        onboarding = false;

        theme.name = "catppuccin";

        # 版本由 nix 管，别让 herdr 自己去拉更新清单。
        update = {
          version_check = false;
          manifest_check = false;
        };

        keys = {
          detach = "prefix+d";
          goto = "prefix+s";

          new_tab = "prefix+ctrl+t";
          previous_tab = "prefix+ctrl+j";
          next_tab = "prefix+ctrl+l";
          move_tab_previous = "prefix+ctrl+shift+j";
          move_tab_next = "prefix+ctrl+shift+l";

          # j/k/i/l 做方向导航，和 tmux/kitty 的习惯一致（h 留给 navigate 模式）。
          focus_pane_left = "prefix+j";
          focus_pane_down = "prefix+k";
          focus_pane_up = "prefix+i";
          focus_pane_right = "prefix+l";

          split_vertical = "prefix+n";
          split_horizontal = "prefix+minus";
        };

        ui = {
          prompt_new_tab_name = false;

          # 用不同字形而不是色点表示 agent 状态，色弱/透明背景下更好认。
          status_indicators = "symbols";

          # 通知走系统通知中心，并且立刻弹出。
          toast = {
            delivery = "system";
            delay_seconds = 0;
            herdr.position = "top-right";
          };

          # 关掉外框、滚动条和 pane 间距：贴近 tmux 的无边框分屏，
          # 也让 kitty 的 background_opacity 连成一片。
          pane_outer_borders = false;
          pane_scrollbars = false;
          pane_gaps = false;

          tab_bar_right = [ { type = "hostname"; } ];
          window_title = "Herdr";
        };

        # 不跨 server 重启保存 pane 历史，session.json 保持小。
        experimental.pane_history = false;
      };
    };

  flake.nixosModules.herdr = m;
  flake.darwinModules.herdr = m;
  flake.sysModules.herdr = m;
  flake.droidModules.herdr = m;
}
