{
  flake.wrappers.kitty =
    {
      wlib,
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
          pkgs.yazi
        ];
        text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./rsync-tool);
      };
    in
    {
      # 内置 kitty wrapper 的扩展（$out/kittyConfig 目录、KITTY_CONFIG_DIRECTORY、
      # clear_all_shortcuts、open-actions.conf/quick-access-terminal.conf/*.py）见 ./module.nix
      themeFile = "Catppuccin-Mocha";
      font.name = "Maple Mono NF CN";
      font.size = 15;
      environment = {
        PATH = "/run/wrappers/bin:$HOME/bin:/run/current-system/sw/bin:$PATH";
      };

      # 清空 kitty 默认快捷键，只保留下面显式定义的 map
      # （由 module.nix 放在所有 map 之前写入）
      clearAllShortcuts = true;

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
        "cmd+k>a" = "launch --type tab --location after coding-agent-status status";
        "cmd+k>space" = "launch --type background cliclick ctrl+shift+space";

        "ctrl+space" = "discard_event";
      };

      mouseBindings = {
        "left click" = "ungrabbed no_op";
        "cmd+left click" = "grabbed,ungrabbed mouse_handle_click selection link prompt";
      };

      # open-actions.conf
      openActions = builtins.readFile ./config/open-actions.conf;

      # quick-access-terminal.conf
      # 没有设置 kitty_conf：默认就用同一个 kitty.conf（相对配置目录解析）
      quickAccessTerminal = {
        columns = 80;
        edge = "center-sized";
        hide_on_focus_loss = true;
        start_as_hidden = true;
        lines = 25;
      };

      # 属性名是相对 kitty 配置目录的路径，所以 keymap 里的
      # `kitten xxx.py`（以及 yazi wrapper 里的 `kitten remote.py`）
      # 都能按原来的相对路径解析
      #
      # 脚本里用到的二进制路径由下面的 scriptVars 在打包期替换：
      # 脚本里写 `@MPV@` / `@RSYNC_TOOL@`，生成出来的文件里就是 store 路径，
      # 运行时不查 PATH（实现见 ./module.nix 的 substituteScriptVars）。
      scriptVars = {
        MPV = pkgs.mpv;
        RSYNC_TOOL = rsync-tool;
      };

      scripts = {
        "actions.py" = ./scripts/actions.py;
        "coding_agent_status.py" = ./scripts/coding_agent_status.py;
        "group_window.py" = ./scripts/group_window.py;
        "neighbor_window.py" = ./scripts/neighbor_window.py;
        "remote.py" = ./scripts/remote.py;
        "select_window.py" = ./scripts/select_window.py;
      };

      # tmux / vi 里运行时对部分按键做特殊处理（原 keymap.conf 的 TMUX 段落），
      # 这部分不做 nix 化，直接作为原始内容追加
      extraConfig = ''
        ${builtins.readFile ./config/extra_font.conf}

        # --------------------------------------- TMUX ------------------------------------------------------
        map --when-focus-on title:^tmux: alt+j
        map --when-focus-on title:^tmux: alt+l
        map --when-focus-on title:^tmux: alt+i
        map --when-focus-on title:^tmux: alt+k
        map --when-focus-on title:^tmux: alt+shift+j
        map --when-focus-on title:^tmux: alt+shift+l
        map --when-focus-on title:^tmux: alt+shift+i
        map --when-focus-on title:^tmux: alt+shift+k
        map --when-focus-on title:^tmux: alt+enter send_text all \x02z
        map --when-focus-on title:^tmux: cmd+n send_text all \x1bn
        map --when-focus-on title:^tmux: ctrl+space
        map --when-focus-on title:^VI: ctrl+space
      '';

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
        # cmd+f show_scrollback 用的分页器
        scrollback_pager = ''nvim -u NONE -R -c 'lua require("kitty+page").entry(INPUT_LINE_NUMBER, CURSOR_LINE, CURSOR_COLUMN)' -'';
      };

      # ui
      settings = {
        active_tab_title_template = "{fmt.fg._e5c07b}{fmt.bg.default}{fmt.bg._e5c07b}{fmt.fg._7b8fe5}{str(num_windows)+' ' if num_windows>1 else ''}{fmt.fg._282c34}{bell_symbol}{title.split(' ')[0]}{fmt.fg._e5c07b}{fmt.bg.default} ";
        tab_title_template = "{fmt.fg._5c6370}{fmt.bg.default}{fmt.bg._5c6370}{fmt.fg._d7d3cb}{str(num_windows)+' ' if num_windows>1 else ''}{fmt.fg._abb2bf}{bell_symbol}{title.split(' ')[0]}{fmt.fg._5c6370}{fmt.bg.default} ";
        tab_bar_edge = "top";
        tab_bar_margin_height = "9 0";
        tab_bar_margin_width = 9;
        tab_bar_style = "separator";
        tab_separator = "";
        tab_bar_min_tabs = 2;
        cursor_shape = "block";
        url_style = "dotted";
        enabled_layouts = "grid,stack";
        window_padding_width = 0;
        show_hyperlink_targets = true;
        cursor_trail = 3;
        cursor_trail_decay = "0.1 0.4";
        cursor_trail_start_threshold = 5;
        background_opacity = 0.75;
        background_blur = 40;
        # neovim catppuccin hl: Normal CursorLine NormalFloat
        transparent_background_colors = "#24273a@0.9 #303347@0.9 #1e2030@0.9";
      };
    };
}
