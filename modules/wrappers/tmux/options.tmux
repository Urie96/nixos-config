set -g extended-keys on
set -g extended-keys-format csi-u
set -g mouse on
set -g history-limit 5000

set -g allow-rename on
set -g automatic-rename off

set -s escape-time 10 # 程序响应esc的延迟，因为有些组合键发送的组合键是^[开头的
set -sg repeat-time 800 # 无需前缀键，重复输入tmux快捷键
set -s focus-events on # 让程序能感知到聚焦

# sesh: smart session manager
set -g detach-on-destroy off  # don't exit tmux when closing a session
bind-key x kill-pane          # skip "kill-pane 1? (y/n)" prompt

# -- display -------------------------------------------------------------------
set-option -g status-position top
set -g base-index 1           # start windows numbering at 1
setw -g pane-base-index 1     # make pane numbering consistent with windows

setw -g automatic-rename on   # rename window to reflect current program
set -g renumber-windows on    # renumber windows when a window is closed

set -g set-titles on          # tmux之外的终端title，比如kitty终端的窗口title
set -g set-titles-string "tmux:#{session_name}[#{host}]"  # e.g. tmux:0[work-macbook]

set -g display-panes-time 10000
set -g display-time 1000      # slightly longer status messages display time

set -g status-interval 10     # redraw status line every 10 seconds

set -g status-left '#{?client_prefix,#[bg=red],}P#[default] [#{session_name}] '
set -g status-right '%m-%d %H:%M'

# monitor
set -g monitor-activity off # 程序有新增输出时, title出现井号#
set -g visual-activity off
set -g monitor-bell on
set -g visual-bell off
set -g bell-action any # 任何窗口的bell都响应

set -g set-clipboard on
