{
  # 插件注册表的声明式管理，补在上游 home-manager 的 programs.herdr 上。
  #
  # 上游模块（inputs.home-manager 的 modules/programs/herdr.nix）已经负责
  # enable/package/settings，并把 config.toml 写到 $XDG_CONFIG_HOME/herdr/，
  # 所以这里不再自带 package/settings 选项，只补它没有的 plugins。
  #
  # 原先是 wrapper + HERDR_CONFIG_PATH：那个变量只换 config.toml 的路径，
  # plugins.json、plugins/、sessions/、session.json、socket 仍然固定在
  # ~/.config/herdr/（源码 src/config/io.rs 的 config_dir() 只看
  # XDG_CONFIG_HOME）。改成写 herdr 的默认位置后，配置和状态在同一处。
  flake.homeModules.herdr =
    {
      config,
      lib,
      pkgs,
      inputs',
      ...
    }:
    let
      cfg = config.programs.herdr;

      # nur-packages 里的 herdr-reviewr：包根目录就是插件根（herdr-plugin.toml +
      # bin/herdr-reviewr），和 `herdr plugin link` 期望的目录结构一致，所以既能
      # 直接注册进注册表，也能单独跑（`herdr-reviewr ~/some/repo`，此时只有 Send
      # 和 last-turn 两个依赖 herdr 的功能不可用）。
      herdrReviewr = inputs'.nur-packages.packages.herdr-reviewr;

      reviewrConfig = {
        theme = "catppuccin";
        default_scope = "uncommitted";
        markdown_view = "rendered";
        diff_view = "split";
        navigator_position = "left";
        toggle_placement = "zoomed";
        toggle_direction = "right";
        auto_open = false;
        follow_file_across_tabs = true;
        scrolloff = 5;
        # url_opener              = ""
        # review_prefix           = ""

        keybindings.comment = [ "c" ];
      };

      # plugins.json 是 herdr 会重写的可变状态（plugin install/link/enable/disable
      # 都写它，另有 .plugins.lock 锁文件），所以不能像 config.toml 那样软链到
      # 只读的 /nix/store。这里构建期算好注册表，activation 时拷成普通文件。
      registry = pkgs.runCommand "herdr-plugins.json" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 ${./registry.py} ${lib.escapeShellArgs (map toString cfg.plugins)} > $out
      '';
    in
    {
      options.programs.herdr.plugins = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = ''
          声明式注册的 herdr 插件。每个包根目录必须有 `herdr-plugin.toml`。

          herdr 不会为这里注册的插件跑 manifest 里的 `[[build]]`，构建产物要在
          derivation 里准备好（二进制放 `$out/bin`，manifest 里的命令写成
          `bin/<name>` 这种相对 plugin_root 的路径）。

          这份列表是权威的：`herdr plugin install/link` 追加的条目会被下次
          activation 覆盖掉。留空则完全不碰 plugins.json。
        '';
      };

      config = {
        home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run install -Dm644 ${registry} "${config.xdg.configHome}/herdr/plugins.json"
        '';

        home.packages = [ herdrReviewr ];

        xdg.configFile."herdr/plugins/config/persiyanov.reviewr/config.toml".source =
          (pkgs.formats.toml { }).generate "herdr-reviewr-config.toml"
            reviewrConfig;

        programs.herdr = {
          enable = true;

          # herdr 重新读 manifest_path 里的 herdr-plugin.toml 补全 action/pane/
          # event，所以注册表里这份极简条目就够了（见 registry.py）。
          plugins = [ herdrReviewr ];

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

              # 默认 prefix+[ 键位别扭，换成 prefix+enter。
              copy_mode = "prefix+enter";

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

              command = [
                {
                  key = "prefix+ctrl+r";
                  type = "plugin_action";
                  command = "persiyanov.reviewr.toggle";
                  description = "reviewr: toggle pane";
                }
              ];
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

              sidebar.agents.rows = [
                [
                  "state_icon"
                  "machine"
                  "workspace"
                ]
                [ "terminal_title" ]
              ];
            };

            # 不跨 server 重启保存 pane 历史，session.json 保持小。
            experimental.pane_history = false;
          };
        };

        wrappers.pi.settings.packages = [
          "${pkgs.herdr}/share/herdr/integrations/pi/herdr-agent-state.ts"
        ];

        programs.codex.hooks.SessionStart = [
          {
            hooks = [
              {
                type = "command";
                command = "${pkgs.bash}/bin/bash ${pkgs.herdr}/share/herdr/integrations/codex/herdr-agent-state.sh session";
                timeout = 10;
              }
            ];
          }
        ];
      };
    };
}
