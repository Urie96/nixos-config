{
  flake.wrappers.tmux =
    {
      wlib,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.wrapperModules.tmux ];
      terminal = "tmux-256color";
      plugins = [
        {
          plugin = pkgs.tmuxPlugins.catppuccin;
          configBefore = ''
            set -g @catppuccin_flavor 'mocha'

            # catppuccin 里 'default' = 用主题色（mocha 下是 mantle #181825，看着就是纯黑），
            # 'none' 才等于 status-style "default"：整行底色 = 终端默认背景色。
            # kitty 只给「背景色跟默认背景色相同的格子」叠 background_opacity/background_blur
            # （kitty/options/definition.py 里 background_opacity 的说明），
            # 所以要么用终端默认色，要么填一个跟 kitty background 完全相同的 hex，两者像素一样。
            set -g @catppuccin_status_background 'none'

            # 圆角得自己画。rounded 预设的角是 #[fg=<状态栏底色>,reverse]：
            # 1. 底色变 default 后它就是非法的 #[fg=none,reverse]，tmux 直接丢掉 → 角变方块；
            # 2. 就算填上颜色，kitty 也会把带 reverse 的格子强制画成不透明：
            #    kitty/cell_vertex.glsl 里 is_special_cell += is_reversed; bg_alpha = 1.0。
            #    所以角那一格永远是一块实心黑，这是“只有圆角还是纯黑”的真正原因。
            # 改成 custom，角直接写 #[fg=<相邻色块底色>,bg=default]，不用 reverse：
            # 墨色 = pill 自己的颜色，格子底色 = 默认底色（和状态栏同一格色 → 一起透明）。
            # 末尾再把数字那一段的配色写回去，否则数字会跟着角的前景色走。
            set -g @catppuccin_window_status_style "custom"
            set -g @catppuccin_window_middle_separator " "
            set -g @catppuccin_window_current_middle_separator " "
            set -g @catppuccin_window_left_separator "#[fg=#{@catppuccin_window_number_color},bg=default]#[fg=#{@thm_crust},bg=#{@catppuccin_window_number_color}]"
            set -g @catppuccin_window_right_separator "#[fg=#{@catppuccin_window_text_color},bg=default]"
            set -g @catppuccin_window_current_left_separator "#[fg=#{@catppuccin_window_current_number_color},bg=default]#[fg=#{@thm_crust},bg=#{@catppuccin_window_current_number_color}]"
            set -g @catppuccin_window_current_right_separator "#[fg=#{@catppuccin_window_current_text_color},bg=default]"

            set -g @catppuccin_window_flags "icon"
            set -g @catppuccin_status_connect_separator "no"
          '';
          configAfter = ''
            # Make the status line pretty and add some modules
            set -g status-right-length 100
            set -g status-left-length 100
            set -g status-left ""
            # 宽屏时才展示 host 和 cpu
            set -g status-right "#{?#{e|>=:#{client_width},120},#{E:@catppuccin_status_host},}"
            set -agF status-right "#{E:@catppuccin_status_cpu}"
            set -ag status-right "#{E:@catppuccin_status_session}"
          '';
        }
        {
          plugin = pkgs.tmuxPlugins.cpu;
        }
      ];

      configBefore =
        let
          scrollback-pager = pkgs.writeShellScript "scrollback-pager" ''
            tmp=$(mktemp "''${TMPDIR:-/tmp}/tmux-scrollback.XXXXXX")

            cleanup() {
              rm -f "$tmp"
            }
            trap cleanup EXIT

            tmux capture-pane -epS - >"$tmp"
            nvim -u NONE -R -c "lua require('kitty+page').entry()" "$tmp"
          '';
          scrollback_pager_popup = pkgs.writeShellScript "scrollback_pager_popup" ''
            PANE=$1

            read -r PL PT PW PH CW CH WH < <(tmux display-message -p -t "$PANE" \
              '#{pane_left} #{pane_top} #{pane_width} #{pane_height} #{client_width} #{client_height} #{window_height}')

            # Window offset within the client: status line at top pushes the window down.
            OY=0
            SP=$(tmux show -g status-position 2>/dev/null)
            [ "''${SP##* }" = top ] && OY=$((CH - WH))

            PX="$PL"
            PY=$((PT + OY))

            # -y is treated by tmux as the popup's BOTTOM edge, so pass PY + height.
            exec tmux display-popup -t "$PANE" -E -b none \
              -w "''$PW" -h "$PH" \
              -x "$PX" -y "$((PY + PH))" ${scrollback-pager}
          '';
        in
        ''
          bind-key C-f run-shell '${scrollback_pager_popup} "#{pane_id}"'  # popup exactly covering the current pane

          ${builtins.readFile ./keybindings.tmux}

          ${builtins.readFile ./options.tmux}
        '';
    };

}
