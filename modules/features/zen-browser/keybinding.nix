{
  flake.homeModules.zen-browser =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Zen 本体 1.24 起把快捷键交给 Firefox 的 CustomKeys 机制
      # （browser/components/customkeys/CustomKeys.sys.mjs），用户定制落在 profile 里的
      # customKeys.json：
      #
      #   { "<key 元素 id>": { modifiers = "accel,shift"; key = "E"; } }
      #
      # 规则：
      #   - 只对 DOM 里已存在的 <key id="..."> 生效，新增不了快捷键（找不到元素直接跳过）；
      #   - key / keycode 至多写一个，key 统一大写；
      #   - modifiers 是逗号分隔的小写名字（accel/alt/control/meta/shift），Zen 自己写出来的按字母序；
      #   - 空对象 {} = 清掉这个键的绑定（等于禁用）。
      #
      # zen-browser-flake 的 programs.zen-browser.profiles.<p>.keyboardShortcuts 选项还在写
      # Zen 已经废弃的 zen-keyboard-shortcuts.json：Zen 启动时读一次、把定制迁进
      # customKeys.json 后删除该文件，且迁移时「CustomKeys 里已定制过」的 id 一律跳过，
      # 所以那个选项只能生效一次，之后改配置不再起作用。这里不用它，直接写 customKeys.json。

      allowedModifiers = [
        "accel"
        "alt"
        "control"
        "meta"
        "shift"
      ];

      # { accel = true; shift = true; } -> "accel,shift"
      modifiersToString =
        modifiers:
        let
          unknown = lib.subtractLists allowedModifiers (lib.attrNames modifiers);
        in
        if unknown != [ ] then
          throw "zen-browser keybinding: 未知的 modifiers：${lib.concatStringsSep ", " unknown}（可选：${lib.concatStringsSep ", " allowedModifiers}）"
        else
          lib.concatStringsSep "," (
            builtins.sort (a: b: a < b) (lib.attrNames (lib.filterAttrs (_: v: v) modifiers))
          );

      # id -> { key?; keycode?; modifiers?; disabled? }  ==>  customKeys.json 的一条。
      mkBinding =
        id: cfg:
        if cfg.disabled or false then
          # {} 表示清除默认绑定。
          lib.nameValuePair id { }
        else
          let
            key = cfg.key or null;
            keycode = cfg.keycode or null;
            modifiers = modifiersToString (cfg.modifiers or { });
          in
          if key == null && keycode == null then
            throw "zen-browser keybinding: ${id} 缺少 key / keycode（禁用请写 disabled = true）"
          else if key != null && keycode != null then
            throw "zen-browser keybinding: ${id} 不能同时写 key 和 keycode"
          else
            lib.nameValuePair id (
              (if key != null then { key = lib.toUpper key; } else { keycode = lib.toUpper keycode; })
              // lib.optionalAttrs (modifiers != "") { inherit modifiers; }
            );

      # id 对应 Zen 的 <key id="...">，也就是 about:keyboard 里显示的条目。没列出来的
      # id 保持 Zen 默认；disabled = true 会写成空对象（等于禁用）。
      #
      # Zen 本体删掉了 mainKeyset 里的 key_prevTab / key_nextTab（只留 mainCommandSet
      # 的 Browser:PrevTab / Browser:NextTab 两个 command），而 customKeys.json 只能改
      # 已存在的 <key>，所以「Cmd+J / Cmd+L 切上一个 / 下一个标签页」在当前版本没法
      # 声明式实现，得等 Zen 把这几个 <key> 加回来。因此 Cmd+J / Cmd+L 各自的默认绑定
      # 这样处理：
      #   - 地址栏（Cmd+L）挪到 Cmd+E；原本占用 Cmd+E 的「在选区中查找」挪到 Cmd+Shift+E。
      #   - 下载面板（Cmd+J）直接禁用，走菜单 / 工具栏；想保留就改成别处空的键位，
      #     例如 Cmd+Shift+Y。
      #   - Cmd+K（key_search = Tools:Search）也能聚焦地址栏。
      shortcuts = {
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
    in
    {
      # 和 zen-browser-flake 自己的 keyboard-shortcuts 片段同一个思路：这里改的是浏览器维护
      # 的 customKeys.json，不是 profile 锁保护的 prefs.js，所以照它的做法不设 requiresLock
      # （浏览器开着时也写）。代价是：Zen 只在启动时读这个文件，而且运行中在 about:keyboard
      # 改键会把内存里的整份数据写回去，可能盖掉我们刚写的条目，所以改完还是要重启 Zen。
      #
      # priority = 200 只影响同一个 profile 内「无 requiresLock 片段」之间的先后；因为我们
      # 不再设 programs.zen-browser.profiles.default.keyboardShortcuts，上游那个写 legacy
      # 文件的片段不会生成，这里是 customKeys.json 唯一的声明式写入者。
      programs.zen-browser.activationFragments.default = [
        {
          priority = 200;
          text = ''
            ZEN_KEYS_FILE=${lib.escapeShellArg "${config.programs.zen-browser.profilesPath}/${config.programs.zen-browser.profiles.default.path}/customKeys.json"}
            ZEN_KEYS='${builtins.toJSON (lib.mapAttrs' mkBinding shortcuts)}'

            # 这个文件同时被 Zen 自己写（about:keyboard 改键、以及从废弃的
            # zen-keyboard-shortcuts.json 迁移），所以做增量合并：只覆盖我们声明的 id，
            # 浏览器写进去的其它条目原样保留。首次启动前文件不存在，直接落一份。
            ZEN_KEYS_TMP="$(mktemp "$ZEN_KEYS_FILE.XXXXXX")"
            if [ -e "$ZEN_KEYS_FILE" ]; then
              ${lib.getExe pkgs.jq} --argjson declared "$ZEN_KEYS" '. + $declared' "$ZEN_KEYS_FILE" >"$ZEN_KEYS_TMP"
            else
              printf '%s\n' "$ZEN_KEYS" >"$ZEN_KEYS_TMP"
            fi

            if ${lib.getExe pkgs.jq} empty "$ZEN_KEYS_TMP" 2>/dev/null; then
              chmod 644 "$ZEN_KEYS_TMP"
              mv -f "$ZEN_KEYS_TMP" "$ZEN_KEYS_FILE"
            else
              rm -f "$ZEN_KEYS_TMP"
              echo "zen-custom-keys: 生成的 JSON 无效，保留原文件" >&2
            fi
          '';
        }
      ];
    };
}
