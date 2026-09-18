{
  flake.darwinModules.yabai = {
    services.yabai = {
      enable = true;
      # package = self.packages.${pkgs.stdenv.hostPlatform.system}.old-pkgs.yabai;
      config = {
        mouse_follows_focus = "on";
        focus_follows_mouse = "off";
        window_origin_display = "default";
        window_placement = "second_child";
        window_zoom_persist = "on";
        window_topmost = "off";
        window_shadow = "off";
        window_animation_duration = 0.0;
        window_opacity_duration = 0.0;
        active_window_opacity = 1.0;
        normal_window_opacity = 0.90;
        window_opacity = "off";
        window_border = "on";
        window_border_width = 2;
        window_border_radius = 12;
        window_border_blur = "off";
        window_border_hidpi = "on";
        active_window_border_color = "0xE0808080";
        normal_window_border_color = "0x00010101";
        insert_feedback_color = "0xE02d74da";
        split_ratio = 0.50;
        split_type = "auto";
        auto_balance = "off";
        top_padding = 0;
        bottom_padding = 0;
        left_padding = 0;
        right_padding = 0;
        window_gap = 3;
        layout = "bsp";
        mouse_modifier = "fn";
        mouse_action1 = "move";
        mouse_action2 = "resize";
        mouse_drop_action = "swap";
      };
      extraConfig = ''
        # clear rules
        for (( ; ; )); do
          if ! yabai -m rule --remove 0 2>/dev/null; then
            break
          fi
        done

        add_rule_unmanage() {
          local app="^$1$"
          local title="$2"
          if [ -z "$title" ]; then
            title=".*"
          else
            title="^$2$"
          fi

          yabai -m rule --add app="$app" title="$title" manage=off
        }

        add_rule_unmanage 系统设置
        add_rule_unmanage 微信 登录
        add_rule_unmanage 微信 软件更新
        add_rule_unmanage 访达
        add_rule_unmanage Raycast
        add_rule_unmanage 数码测色计
        add_rule_unmanage Tinycast
        add_rule_unmanage "Lark Helper" "图片"

        # yabai -m rule --add app="^微信$" title!="^登录$" space="^2"
        # yabai -m rule --add app="^Code$" title=="^http .*$" space="^7"
        # yabai -m rule --add app="^飞书$" space="^2"
        # yabai -m rule --add app="^Alacritty$" space="^3"

        # yabai -m query --windows --space 2
        # yabai -m rule --list

        echo "yabai configuration loaded.."
      '';
    };

  };
}
