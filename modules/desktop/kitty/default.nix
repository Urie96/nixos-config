{
  self,
  ...
}:
{
  flake.homeModules.kitty =
    {
      lib,
      pkgs,
      ...
    }:
    let
      # remote.py 的 pull/push 会在新 tab 里执行它。原来是放在 scripts/ 下靠 PATH 查找的，
      # 现在做成真正的包，由 scriptVars 把绝对路径注入到 remote.py 里。
      # writeShellApplication 自己会写 shebang，所以去掉源文件的 shebang 那一行。
      rsync-tool = pkgs.writeShellApplication {
        name = "rsync-tool";
        runtimeInputs = [
          pkgs.rsync
          pkgs.openssh
          self.packages.${pkgs.stdenv.hostPlatform.system}.yazi
        ];
        text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./rsync-tool);
      };

      # 写进 `~/.config/kitty/` 时把 `@NAME@` 替换成 scriptVars.NAME 的绝对路径
      # （在求值时完成，脚本运行时不再查 PATH）。
      # 值为 package 时用 lib.getExe 取可执行文件，为 path 时原样使用。
      scriptVars = {
        MPV = pkgs.mpv;
        RSYNC_TOOL = rsync-tool;
      };
      toScriptVar = value: if lib.isDerivation value then lib.getExe value else toString value;
      scriptVarSubstitutions = lib.mapAttrsToList (name: value: {
        from = "@${name}@";
        to = toScriptVar value;
      }) scriptVars;
      substituteScriptVars =
        content:
        let
          from = map (s: s.from) scriptVarSubstitutions;
          to = map (s: s.to) scriptVarSubstitutions;
        in
        builtins.replaceStrings from to content;

      # 键相对 `~/.config/kitty/`：
      #   - open-actions.conf、`*.py` 由 kitty 按配置目录解析（`kitten <name>.py`）；
      #   - shaders/ 下的文件被 settings.custom_shaders 引用。
      configFiles = {
        "open-actions.conf" = ./config/open-actions.conf;
        "actions.py" = ./scripts/actions.py;
        "group_window.py" = ./scripts/group_window.py;
        "neighbor_window.py" = ./scripts/neighbor_window.py;
        "remote.py" = ./scripts/remote.py;
        "select_window.py" = ./scripts/select_window.py;
        "shaders/cursor-trail-lightning-slow.pipeline" =
          ./config/shaders/cursor-trail-lightning-slow.pipeline;
        "shaders/cursor-trail-lightning-slow.slang" = ./config/shaders/cursor-trail-lightning-slow.slang;
        "shaders/cursor-trail-bubbles.pipeline" = ./config/shaders/cursor-trail-bubbles.pipeline;
      };
    in
    {
      programs.kitty = {
        enable = true;
        # macOS 用 nur-packages 里基于上游 dmg 的 kitty（含上游签名），
        # 其他系统仍用 nixpkgs 的 pkgs.kitty。
        package =
          if pkgs.stdenv.hostPlatform.isDarwin then
            self.inputs.nur-packages.packages.${pkgs.stdenv.hostPlatform.system}.kitty
          else
            pkgs.kitty;
        themeFile = "Catppuccin-Mocha";
        font = {
          name = "Maple Mono NF CN";
          size = 15;
        };

        # GUI 启动（macOS 的 .app、Linux 的 desktop entry）拿到的 PATH 很短，
        # 这里给 kitty 启动的子进程补上系统/用户目录。
        # `env` 的值由 kitty 递归展开：$PATH / $HOME 取 kitty 自己的进程环境。
        environment.PATH = "/run/wrappers/bin:$HOME/bin:/run/current-system/sw/bin:$PATH";

        # 原来 wrapper 只往 kitty.conf 写 `shell_integration no-rc`，不改 shell 的 rc 文件。
        # Home Manager 的 shellIntegration 会额外往 fish/zsh/bash 配置里塞 source 片段，
        # 所以把 mode 置空，继续用 settings 里那一行，输出和以前一致。
        shellIntegration.mode = null;

        # 清空 kitty 默认快捷键，只保留下面显式定义的 map。
        # mkOrder 500 保证 `clear_all_shortcuts` 排在所有 `map` 之前。
        # extra_font.conf 和 TMUX 段落（tmux / vi 里运行时对部分按键做特殊处理）
        # 不做 nix 化，直接作为原始内容追加。
        extraConfig = lib.mkMerge [
          (lib.mkOrder 500 ''
            clear_all_shortcuts yes
          '')
          (lib.mkOrder 900 ''
            ${builtins.readFile ./config/extra_font.conf}

            ${builtins.readFile ./config/tmux_keys.conf}
          '')
        ];

        # https://sw.kovidgoyal.net/kitty/keyboard-protocol/#functional-key-definitions
        keybindings = {
          "cmd+BACKSPACE" = "send_text all \\x15";
          "cmd+LEFT" = "send_text all \\x1bOH";
          "cmd+RIGHT" = "send_text all \\x1bOF";
          "cmd+c" = "copy_to_clipboard";
          "cmd+v" = "paste_from_clipboard";
          "cmd+e" = "kitten edit_and_paste.py";
          # 原 keymap.conf 里 cmd+o 先绑 next_layout 又被 goto_tab -1 覆盖，这里保持后者
          "cmd+o" = "goto_tab -1";
          "cmd+f" = "show_scrollback";
          "cmd+h" = "kitten actions.py";
          "cmd+j" = "previous_tab";
          "cmd+l" = "next_tab";
          "cmd+i" = "next_tab";
          "alt+esc" = "kitten select_window.py";
          "alt+j" = "neighboring_window left";
          "alt+l" = "neighboring_window right";
          "alt+i" = "neighboring_window top";
          "alt+k" = "neighboring_window bottom";
          "alt+shift+j" = "move_window left";
          "alt+shift+l" = "move_window right";
          "alt+shift+i" = "move_window top";
          "alt+shift+k" = "move_window bottom";
          "alt+enter" = "toggle_layout stack";

          "cmd+d" = "detach_window ask";
          "cmd+n" = "launch --cwd=current";
          "cmd+shift+j" = "move_tab_backward";
          "cmd+shift+k" = "clear_terminal reset active";
          "cmd+shift+l" = "move_tab_forward";
          "cmd+shift+n" = "new_window";
          "cmd+t" = "new_tab_with_cwd !neighbor";
          "cmd+w" = "close_window_with_confirmation";
          "ctrl+shift+x" = "scroll_to_prompt +1";

          "cmd+k>f" = "launch --type tab --location after pick-window";
          "cmd+k>v" = ''launch --type tab --location after nvim -c 'call feedkeys("\<Space>bn")' '';
          "cmd+k>t" =
            ''launch --type tab --location after lazydeck --eval "deck.api.feedkeys('/')" /quick-access-tools'';
          "cmd+k>space" = "launch --type background cliclick ctrl+shift+space";

          "ctrl+space" = "discard_event";
        };

        mouseBindings = {
          "left click" = "ungrabbed no_op";
          "cmd+left click" = "grabbed,ungrabbed mouse_handle_click selection link prompt";
        };

        # quick-access-terminal.conf
        # 没有设置 kitty_conf：默认就用同一个 kitty.conf（相对配置目录解析）
        quickAccessTerminalConfig = {
          columns = 80;
          edge = "center-sized";
          hide_on_focus_loss = true;
          start_as_hidden = true;
          lines = 25;
        };

        # control
        settings = {
          shell_integration = "no-rc";
          allow_remote_control = true;
          confirm_os_window_close = 0;
          listen_on = "unix:/tmp/mykitty";
          macos_hide_from_tasks = false;
          macos_option_as_alt = true;
          macos_quit_when_last_window_closed = true;
          mouse_hide_wait = 2;
          visual_bell_duration = 0.1;
          hide_window_decorations = true;
          editor = "nvim";
          visual_window_select_characters = "ASDFGHJKL;";
          # cmd+f show_scrollback 用的分页器（lua/kitty+page.lua 在 neovim 配置里）
          scrollback_pager = ''nvim -u NONE -R -c 'lua require("kitty+page").entry(INPUT_LINE_NUMBER, CURSOR_LINE, CURSOR_COLUMN)' -'';

          # ui
          active_tab_title_template = "{fmt.fg._e5c07b}{fmt.bg.default}{fmt.bg._e5c07b}{fmt.fg._7b8fe5}{str(num_windows)+' ' if num_windows>1 else ''}{fmt.fg._282c34}{bell_symbol}{title}{fmt.fg._e5c07b}{fmt.bg.default} ";
          # title.split(' ')[0]
          tab_title_template = "{fmt.fg._5c6370}{fmt.bg.default}{fmt.bg._5c6370}{fmt.fg._d7d3cb}{str(num_windows)+' ' if num_windows>1 else ''}{fmt.fg._abb2bf}{bell_symbol}{title}{fmt.fg._5c6370}{fmt.bg.default} ";
          tab_bar_background = "#1E1E2E";
          inactive_tab_background = "#1E1E2E";
          tab_bar_edge = "top";
          tab_bar_margin_height = "9 0";
          tab_bar_margin_width = 9;
          tab_bar_style = "separator";
          tab_separator = ''" "'';
          tab_bar_min_tabs = 2;
          # 光标本体颜色，和 blaze / bubbles 的琥珀色对齐。
          # shader 里的颜色是 linear RGB（blaze 的 TRAIL_COLOR = 1.0, 0.725, 0.161），
          # kitty.conf 这里是 sRGB，换算后就是 #ffdd70。
          cursor = "#ffdd70";
          cursor_shape = "block";
          url_style = "dotted";
          enabled_layouts = "grid,stack";
          window_padding_width = 0;
          show_hyperlink_targets = true;
          custom_shaders = "cursor-trail-bubbles cursor-trail-blaze";
          cursor_trail = 3;
          # 只影响内置的 cursor-trail-default（拖影），bubbles 管线不引用它
          cursor_trail_decay = "0.1 0.4";
          cursor_trail_start_threshold = 5;
          background_opacity = 0.75;
          background_blur = 40;
          # neovim catppuccin hl: Normal CursorLine NormalFloat
          transparent_background_colors = "#24273a@0.9 #303347@0.9 #1e2030@0.9";
        };
      };

      xdg.configFile = lib.mapAttrs' (
        name: file:
        lib.nameValuePair "kitty/${name}" {
          text = substituteScriptVars (builtins.readFile file);
        }
      ) configFiles;
    };
}
