-- ============================================================================
-- Hyprland 配置（从 niri 迁移）
-- 原 niri 配置: ~/dotfile/home/.config/niri/（config.kdl / keymap.kdl / rule.kdl / outputs.kdl）
--
-- 说明: Hyprland 0.55 起配置从 hyprlang(.conf) 迁移到 Lua，
--       0.56 仍兼容 .conf，但 0.57 起移除，所以这里直接写 Lua。
-- 参考: https://wiki.hypr.land/Configuring/Start/
-- ============================================================================

------------------
---- MONITORS ----
------------------

-- niri outputs.kdl: ViewSonic VX2771-4K-HD scale 1.5
hl.monitor {
  output = 'desc:ViewSonic Corporation VX2771-4K-HD',
  mode = 'preferred',
  position = 'auto',
  scale = 1.5,
}

-- 兜底: 未匹配到的显示器使用默认设置
hl.monitor {
  output = '',
  mode = 'preferred',
  position = 'auto',
  scale = 'auto',
}

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config {
  general = {
    -- niri layout.gaps 8
    gaps_in = 8,
    gaps_out = 8,

    -- niri focus-ring: width 3, active #7fc8ff, inactive #505050
    border_size = 3,
    col = {
      active_border = 'rgba(7fc8ffee)',
      inactive_border = 'rgba(505050aa)',
    },

    -- 使用 scrolling 布局（最接近 niri 的列式滚动布局）
    layout = 'scrolling',
  },

  decoration = {
    -- niri rule.kdl: 所有窗口圆角 20
    rounding = 20,

    -- niri shadow: softness 30, offset y=5, color #0007
    shadow = {
      enabled = true,
      range = 30,
      color = 'rgba(00000077)',
      offset = { 0, 5 },
    },
  },

  -- scrolling 布局参数（对应 niri 的 layout 段）
  scrolling = {
    -- niri default-column-width 1.0
    column_width = 1.0,
    -- niri preset-column-widths 0.5 / 0.75 / 1.0（Alt+O 循环切换）
    explicit_column_widths = '0.5,0.75,1.0',
    -- niri center-focused-column "never": 聚焦时只滚入视野，不居中
    focus_fit_method = 1,
    -- 新窗口往右排列
    direction = 'right',
  },

  misc = {
    disable_hyprland_logo = true,
  },
}

----------------
---- INPUT ----
----------------

hl.config {
  input = {
    kb_layout = 'us',
    numlock_by_default = true,
    repeat_delay = 200, -- niri repeat-delay 600
    repeat_rate = 25, -- niri repeat-rate 25
    follow_mouse = 1, -- 近似 niri warp-mouse-to-focus: 鼠标移动跟随焦点

    touchpad = {
      tap_to_click = true, -- niri touchpad.tap
      natural_scroll = true, -- niri touchpad.natural-scroll
    },
  },
}

---------------------
---- AUTOSTART ------
---------------------

-- niri spawn-at-startup "noctalia-shell"
hl.on('hyprland.start', function()
  hl.exec_cmd 'noctalia-shell'
  hl.exec_cmd 'hyprpolkitagent' -- polkit 认证弹窗
  hl.exec_cmd 'hypridle' -- 空闲锁屏（hypridle.conf）
end)

---------------------
---- WORKSPACES -----
---------------------

-- 命名工作区（沿用 sway 布局: web / dev / im），persistent 保持常驻
-- 注意: Lua API 中命名工作区用 "name:xxx" 形式（"1:web" 这种 id:name 写法不会被解析）
hl.workspace_rule { workspace = 'name:web', persistent = true }
hl.workspace_rule { workspace = 'name:dev', persistent = true }
hl.workspace_rule { workspace = 'name:im', persistent = true }

---------------------
--- WINDOW RULES ----
---------------------

-- 对应 niri rule.kdl

-- 浏览器 -> web 工作区
hl.window_rule {
  match = {
    class = [[^(firefox|librewolf|chromium|chromium-browser|google-chrome|org\.chromium\.Chromium|brave-browser|zen|org\.zen-browser\.zen)$]],
  },
  workspace = 'name:web',
}

-- 终端和编辑器 -> dev 工作区
hl.window_rule {
  match = {
    class = [[^(com\.mitchellh\.ghostty|Alacritty|foot|footclient|kitty|org\.wezfurlong\.wezterm|xterm|emacs|neovide)$]],
  },
  workspace = 'name:dev',
}

-- IM / 聊天 -> im 工作区
hl.window_rule {
  match = {
    class = [[^(org\.telegram\.desktop|[Ss]ignal|[Ff]erdium|Element|discord|Slack|thunderbird|evolution|org\.gnome\.Fractal|im\.nheko\.Nheko)$]],
  },
  workspace = 'name:im',
}

-- Firefox/LibreWolf PiP 悬浮
hl.window_rule {
  match = { class = [[^(firefox|librewolf)$]], title = [[^Picture-in-Picture$]] },
  float = true,
}

-- Firefox 分享指示条悬浮
hl.window_rule {
  match = { class = [[^(firefox|librewolf)$]], title = [[^(Firefox|LibreWolf) — Sharing Indicator$]] },
  float = true,
}

-- OpenSSH 密码对话框悬浮
hl.window_rule {
  match = { title = [[^OpenSSH Authentication Passphrase request$]] },
  float = true,
}

-- 注: niri 的 kitty open-maximized / draw-border-with-background 在 Hyprland 中不需要:
--   scrolling 布局 column_width=1.0 时窗口默认即全宽；
--   Hyprland 的边框不绘制背景，不影响 kitty 透明背景。

---------------------
---- KEYBINDINGS ----
---------------------

-- niri 的 Mod 在 TTY 下就是 Super（keyd 里 Super+c/v 已映射为 Ctrl+c/v）
local mainMod = 'SUPER'

-- 启动器 / 工具（Noctalia IPC，对应 niri keymap.kdl）
hl.bind(
  mainMod .. ' + space',
  hl.dsp.exec_cmd 'noctalia-shell ipc call launcher toggle',
  { description = 'App Launcher' }
)
hl.bind(
  mainMod .. ' + SHIFT + D',
  hl.dsp.exec_cmd 'noctalia-shell ipc call launcher clipboard',
  { description = 'Clipboard' }
)
hl.bind(
  mainMod .. ' + SHIFT + period',
  hl.dsp.exec_cmd 'noctalia-shell ipc call launcher emoji',
  { description = 'Emoji Picker' }
)
hl.bind(
  mainMod .. ' + SHIFT + P',
  hl.dsp.exec_cmd 'noctalia-shell ipc call plugin:rbw-provider toggle',
  { description = 'Password Manager' }
)
hl.bind(
  mainMod .. ' + G',
  hl.dsp.exec_cmd 'noctalia-shell ipc call plugin:nostr-chat toggle',
  { description = 'Janet' }
)
hl.bind(
  mainMod .. ' + P',
  hl.dsp.exec_cmd 'noctalia-shell ipc call plugin:display-config toggle',
  { description = 'Display Config' }
)
hl.bind(
  mainMod .. ' + ALT + L',
  hl.dsp.exec_cmd 'noctalia-shell ipc call lockScreen lock',
  { locked = true, description = 'Lock Screen' }
)
hl.bind(
  mainMod .. ' + A',
  hl.dsp.exec_cmd 'noctalia-shell ipc call plugin:audio-provider toggle',
  { description = 'Audio Chooser' }
)

-- 屏幕阅读器开关
hl.bind(mainMod .. ' + ALT + S', hl.dsp.exec_cmd 'pkill orca || exec orca', { locked = true })

-- 音频 / 媒体 / 亮度（Noctalia OSD）
hl.bind(
  'XF86AudioRaiseVolume',
  hl.dsp.exec_cmd 'noctalia-shell ipc call volume increase',
  { locked = true, repeating = true }
)
hl.bind(
  'XF86AudioLowerVolume',
  hl.dsp.exec_cmd 'noctalia-shell ipc call volume decrease',
  { locked = true, repeating = true }
)
hl.bind('XF86AudioMute', hl.dsp.exec_cmd 'noctalia-shell ipc call volume muteOutput', { locked = true })
hl.bind('XF86AudioMicMute', hl.dsp.exec_cmd 'noctalia-shell ipc call volume muteInput', { locked = true })
hl.bind('XF86AudioPlay', hl.dsp.exec_cmd 'noctalia-shell ipc call media playPause', { locked = true })
hl.bind('XF86AudioStop', hl.dsp.exec_cmd 'noctalia-shell ipc call media stop', { locked = true })
hl.bind('XF86AudioPrev', hl.dsp.exec_cmd 'noctalia-shell ipc call media previous', { locked = true })
hl.bind('XF86AudioNext', hl.dsp.exec_cmd 'noctalia-shell ipc call media next', { locked = true })
hl.bind(
  'XF86MonBrightnessUp',
  hl.dsp.exec_cmd 'noctalia-shell ipc call brightness increase',
  { locked = true, repeating = true }
)
hl.bind(
  'XF86MonBrightnessDown',
  hl.dsp.exec_cmd 'noctalia-shell ipc call brightness decrease',
  { locked = true, repeating = true }
)

-- 窗口
hl.bind(mainMod .. ' + Q', hl.dsp.window.close(), { description = 'Close Window' })

-- 列导航（niri focus-column-left/right）
hl.bind('ALT + J', hl.dsp.focus { direction = 'left' })
hl.bind('ALT + L', hl.dsp.focus { direction = 'right' })
hl.bind('ALT + SHIFT + J', hl.dsp.window.move { direction = 'left' })
hl.bind('ALT + SHIFT + L', hl.dsp.window.move { direction = 'right' })

-- 显示器导航（niri focus-monitor-*; Hyprland 0.54+ movefocus 在边缘会跨显示器）
hl.bind(mainMod .. ' + SHIFT + left', hl.dsp.focus { direction = 'left' })
hl.bind(mainMod .. ' + SHIFT + down', hl.dsp.focus { direction = 'down' })
hl.bind(mainMod .. ' + SHIFT + up', hl.dsp.focus { direction = 'up' })
hl.bind(mainMod .. ' + SHIFT + right', hl.dsp.focus { direction = 'right' })
-- 移动窗口到相邻显示器（niri move-column-to-monitor-*）
hl.bind(mainMod .. ' + SHIFT + CTRL + left', hl.dsp.window.move { direction = 'left' })
hl.bind(mainMod .. ' + SHIFT + CTRL + down', hl.dsp.window.move { direction = 'down' })
hl.bind(mainMod .. ' + SHIFT + CTRL + up', hl.dsp.window.move { direction = 'up' })
hl.bind(mainMod .. ' + SHIFT + CTRL + right', hl.dsp.window.move { direction = 'right' })

-- 工作区切换（niri focus-workspace-down/up，e±1 = 在已有工作区间切换）
hl.bind('ALT + K', hl.dsp.focus { workspace = 'e+1' })
hl.bind('ALT + I', hl.dsp.focus { workspace = 'e-1' })
hl.bind('ALT + SHIFT + K', hl.dsp.window.move { workspace = 'e+1' })
hl.bind('ALT + SHIFT + I', hl.dsp.window.move { workspace = 'e-1' })

-- 直接切换命名工作区（niri Alt+Q/W/E）
hl.bind('ALT + Q', hl.dsp.focus { workspace = 'name:web' })
hl.bind('ALT + W', hl.dsp.focus { workspace = 'name:dev' })
hl.bind('ALT + E', hl.dsp.focus { workspace = 'name:im' })
hl.bind('ALT + SHIFT + Q', hl.dsp.window.move { workspace = 'name:web' })
hl.bind('ALT + SHIFT + W', hl.dsp.window.move { workspace = 'name:dev' })
hl.bind('ALT + SHIFT + E', hl.dsp.window.move { workspace = 'name:im' })

-- 滚轮切工作区（niri Mod+WheelScroll*）
hl.bind(mainMod .. ' + mouse_down', hl.dsp.focus { workspace = 'e+1' })
hl.bind(mainMod .. ' + mouse_up', hl.dsp.focus { workspace = 'e-1' })
hl.bind(mainMod .. ' + CTRL + mouse_down', hl.dsp.window.move { workspace = 'e+1' })
hl.bind(mainMod .. ' + CTRL + mouse_up', hl.dsp.window.move { workspace = 'e-1' })
-- 横向滚轮切列（niri Mod+WheelScrollRight/Left）
hl.bind(mainMod .. ' + mouse_right', hl.dsp.focus { direction = 'right' })
hl.bind(mainMod .. ' + mouse_left', hl.dsp.focus { direction = 'left' })
hl.bind(mainMod .. ' + CTRL + mouse_right', hl.dsp.window.move { direction = 'right' })
hl.bind(mainMod .. ' + CTRL + mouse_left', hl.dsp.window.move { direction = 'left' })

-- 列宽
hl.bind('ALT + O', hl.dsp.layout 'colresize +conf') -- niri Alt+O switch-preset-column-width（0.5/0.75/1.0 循环）
hl.bind(mainMod .. ' + minus', hl.dsp.layout 'colresize -0.1') -- niri Mod+Minus set-column-width "-10%"
hl.bind(mainMod .. ' + equal', hl.dsp.layout 'colresize +0.1') -- niri Mod+Equal set-column-width "+10%"

-- 全屏 / 悬浮 / 退出
hl.bind('ALT + RETURN', hl.dsp.window.fullscreen { mode = 'fullscreen', action = 'toggle' }) -- niri Alt+Return fullscreen-window
hl.bind('ALT + F', hl.dsp.window.float { action = 'toggle' }) -- niri Alt+F toggle-window-floating
hl.bind(mainMod .. ' + SHIFT + E', hl.dsp.exit()) -- niri Mod+Shift+E quit

-- 截图（对应 niri Print=screenshot / Ctrl+Print=screenshot-screen / Alt+Print=screenshot-window）
hl.bind('Print', hl.dsp.exec_cmd 'grim ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d-%H-%M-%S).png')
hl.bind('CTRL + Print', hl.dsp.exec_cmd 'hyprshot -m output')
hl.bind('ALT + Print', hl.dsp.exec_cmd 'hyprshot -m window')

-- 注: niri 的 Mod+O toggle-overview / Mod+Escape shortcuts-inhibit /
--     Mod+Shift+Slash hotkey-overlay 在 Hyprland 中没有对应功能，未迁移。
