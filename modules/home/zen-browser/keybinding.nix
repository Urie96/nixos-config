{
  flake.homeModules.zen-browser =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # keyboardShortcuts 的 modifiers 五个字段都是必填，这里给默认值，
      # 条目里只写需要打开的键。未被覆盖的一律是 false。
      defaultModifiers = {
        control = false;
        alt = false;
        shift = false;
        meta = false;
        accel = false;
      };

      # id -> { key; modifiers?; disabled? }  ==>  keyboardShortcuts 的一个条目。
      # 顺序由 mapAttrsToList 按属性名排序决定，快捷键本身对顺序不敏感。
      mkShortcut =
        id: cfg:
        if cfg.disabled or false then
          {
            inherit id;
            disabled = true;
          }
        else
          {
            inherit id;
            key = cfg.key or (throw "zen-browser keybinding: ${id} 缺少 key（禁用请写 disabled = true）");
            modifiers = defaultModifiers // (cfg.modifiers or { });
          };

      # 切换到上一个 / 下一个标签页：Zen 的 mainKeyset 里没有这两个 <key>
      # （上游把 key_prevTab / key_nextTab 删掉了），只在 mainCommandSet 里留下
      # `Browser:PrevTab` / `Browser:NextTab` 两个 command。上游 home-manager
      # 模块的 keyboardShortcuts 只按 id 合并「已存在」的条目，加不了新条目，
      # 所以这两条得自己 upsert 进 zen-keyboard-shortcuts.json，action 指向那两个
      # command（见 browser.xhtml 的 mainCommandSet + browser-sets.js 的
      # case "Browser:PrevTab" / "Browser:NextTab"）。
      customShortcuts = [
        {
          id = "zen-tab-previous-custom";
          key = "j";
          action = "Browser:PrevTab";
        }
        {
          id = "zen-tab-next-custom";
          key = "l";
          action = "Browser:NextTab";
        }
      ];

      # Zen 从 JSON 反序列化时字段是必填的，group 还必须在 VALID_SHORTCUT_GROUPS
      # 里（否则抛错、整份快捷键重置），internal = true 的条目不会被
      # _applyShortcuts 真正挂到 DOM 上。
      toCustomShortcut = s: {
        inherit (s) id key action;
        keycode = "";
        group = "windowAndTabManagement";
        # 没有对应的 l10n id：设置页的标签会退回显示 action 字符串。
        l10nId = null;
        modifiers = defaultModifiers // {
          accel = true;
        };
        disabled = false;
        reserved = false;
        internal = false;
      };
    in
    {
      programs.zen-browser.profiles.default.keyboardShortcuts = lib.mapAttrsToList mkShortcut {
        addBookmarkAsKb.disabled = true;
        key_newNavigator.disabled = true;

        zen-toggle-pin-tab = {
          key = "D";
          modifiers.accel = true;
        };

        zen-workspace-forward = {
          key = "N";
          modifiers.accel = true;
        };

        zen-duplicate-tab = {
          key = "D";
          modifiers.accel = true;
          modifiers.shift = true;
        };

        goBackKb = {
          key = "O";
          modifiers.control = true;
        };

        goForwardKb = {
          key = "I";
          modifiers.control = true;
        };

        # Cmd+J / Cmd+L 让给上一个 / 下一个标签页（见上面的 customShortcuts），
        # 两个被顶掉的默认绑定这样处理：
        #   - 地址栏（Cmd+L）挪到 Cmd+E；原本占用 Cmd+E 的“在选区中查找”挪到 Cmd+Shift+E。
        #   - 下载面板（Cmd+J）直接禁用，走菜单 / 工具栏；想保留就改成别处空的键位，
        #     例如 Cmd+Shift+Y。
        # 另外 Cmd+K（key_search = Tools:Search）也能聚焦地址栏。
        focusURLBar = {
          key = "E";
          modifiers.accel = true;
        };

        key_findSelection = {
          key = "E";
          modifiers.accel = true;
          modifiers.shift = true;
        };

        key_openDownloads.disabled = true;
      };

      # 和上游 keyboard-shortcuts 片段（priority = 100）同一个思路：这里改的是
      # 浏览器自己维护的 zen-keyboard-shortcuts.json，不是 profile 锁保护的 prefs.js，
      # 所以照上游的做法不设 requiresLock（浏览器开着时也写，重启 Zen 后生效）。
      # 放在上游片段之后跑，让 upsert 的结果成为文件的最终状态。
      programs.zen-browser.activationFragments.default = [
        {
          priority = 200;
          text = ''
            ZEN_SHORTCUTS_FILE=${lib.escapeShellArg "${config.programs.zen-browser.profilesPath}/${config.programs.zen-browser.profiles.default.path}/zen-keyboard-shortcuts.json"}
            ZEN_CUSTOM_SHORTCUTS='${builtins.toJSON (map toCustomShortcut customShortcuts)}'

            # 首次启动前这个文件还不存在，Zen 会自己建；建好之后再 switch 就会补上。
            if [ -f "$ZEN_SHORTCUTS_FILE" ]; then
              ZEN_SHORTCUTS_TMP="$(mktemp "$ZEN_SHORTCUTS_FILE.XXXXXX")"
              ${lib.getExe pkgs.jq} --argjson custom "$ZEN_CUSTOM_SHORTCUTS" '
                .shortcuts =
                  ((.shortcuts // [])
                    | map(select(.id as $id | ($custom | map(.id) | index($id)) | not)))
                  + $custom
              ' "$ZEN_SHORTCUTS_FILE" >"$ZEN_SHORTCUTS_TMP"

              if ${lib.getExe pkgs.jq} empty "$ZEN_SHORTCUTS_TMP" 2>/dev/null; then
                chmod 644 "$ZEN_SHORTCUTS_TMP"
                mv -f "$ZEN_SHORTCUTS_TMP" "$ZEN_SHORTCUTS_FILE"
              else
                rm -f "$ZEN_SHORTCUTS_TMP"
                echo "zen-keyboard-shortcuts: 生成的 JSON 无效，保留原文件" >&2
              fi
            else
              echo "zen-keyboard-shortcuts: $ZEN_SHORTCUTS_FILE 不存在，等 Zen 首次启动后再 switch"
            fi
          '';
        }
      ];
    };
}
