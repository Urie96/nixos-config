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

  # 安装入口：modules/scene/base.nix 里 `imports = with self.<class>; [ herdr ]` 引用。
  # 通用的 install 模块只为声明 `wrappers.herdr.*` 选项，真正落地靠 enable 打开。
  # 同时把 herdr 自带的 pi 集成脚本塞进 pi wrapper 的 packages，
  # 这样 pane 里的 pi 会把 agent 状态报给 herdr。
  #
  # 注意：这些输出必须和上面的 `flake.wrappers.herdr` 写在同一个 attrset 里。
  # 用 `{ ... } // { ... }` 合并会把整个 `flake` 属性覆盖掉（`//` 是浅合并），
  # `flake.wrappers.herdr` 里的 settings 会静默消失，生成出一份空配置。
  flake.nixosModules.herdr = {
    pkgs,
    ...
  }: {
    wrappers.herdr.enable = true;
    wrappers.pi.settings.packages = [
      "${pkgs.herdr}/share/herdr/integrations/pi/herdr-agent-state.ts"
    ];
  };
  flake.darwinModules.herdr = {
    pkgs,
    ...
  }: {
    wrappers.herdr.enable = true;
    wrappers.pi.settings.packages = [
      "${pkgs.herdr}/share/herdr/integrations/pi/herdr-agent-state.ts"
    ];
  };
  flake.sysModules.herdr = {
    pkgs,
    ...
  }: {
    wrappers.herdr.enable = true;
    wrappers.pi.settings.packages = [
      "${pkgs.herdr}/share/herdr/integrations/pi/herdr-agent-state.ts"
    ];
  };
  flake.droidModules.herdr = {
    pkgs,
    ...
  }: {
    wrappers.herdr.enable = true;
    wrappers.pi.settings.packages = [
      "${pkgs.herdr}/share/herdr/integrations/pi/herdr-agent-state.ts"
    ];
  };
}
