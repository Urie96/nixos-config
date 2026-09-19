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
            set -g @catppuccin_window_status_style "rounded"
            set -g @catppuccin_window_flags "icon"
            set -g @catppuccin_status_connect_separator "no"

            # Make the status line pretty and add some modules
            set -g status-right-length 100
            set -g status-left-length 100
            set -g status-left ""
            # 宽屏时才展示host
            set -g status-right "#{?#{e|>=:#{client_width},120},#{E:@catppuccin_status_host},}#{E:@catppuccin_status_session}"
          '';
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
