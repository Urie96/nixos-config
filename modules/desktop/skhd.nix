{
  flake.darwinModules.skhd =
    { inputs', ... }:
    {

      services = {
        skhd = {
          enable = true;
          package = inputs'.nur-packages.packages.skhd-zig;
          skhdConfig = ''
            .shell "/run/current-system/sw/bin/bash"

            cmd + shift - w : echo
            cmd - m : echo
            cmd - q : echo
            rcmd + ralt + rctrl + shift - a : open "https://cloud.bytedance.net/argos/streamlog/info_overview/log_id_search?logId=$(pbpaste)"

            rcmd + ralt + rctrl - i | cmd + ctrl - q

            alt - space : yabai -m space --balance
            shift + alt - a : yabai -m window --space 1 --focus
            shift + alt - s : yabai -m window --space 2 --focus
            shift + alt - d : yabai -m window --space 3 --focus
            shift + alt - f : yabai -m window --space 4 --focus
            shift + alt - g : yabai -m window --space 5 --focus
            shift + alt - q : yabai -m window --space 6 --focus
            shift + alt - w : yabai -m window --space 7 --focus
            shift + alt - e : yabai -m window --space 8 --focus
            shift + alt - r : yabai -m window --space 9 --focus
            shift + alt - t : yabai -m window --space 10 --focus

            alt - return [
              "kitty" ~
              * : yabai -m window --toggle zoom-fullscreen
            ]

            alt - o [
              "kitty" ~
              * : yabai -m space --rotate 90
            ]

            cmd - h [
              "kitty" ~
              * : true
            ]

            # ctrl - space [
            #   "kitty" ~
            #   * | ctrl + shift - space
            # ]
          '';
        };
      };
    };
}
