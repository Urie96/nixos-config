bind-key f display-popup -E -w 100% -h 100% -b none 'pick-window'
bind-key a display-popup -E -w 80% -h 80% -b rounded 'coding-agent-status status'
bind-key v new-window nvim -c 'call feedkeys("\<Space>bn")'
# bind-key C-space display-popup -T ㄓ -h 2 -w 100% -EE -b none \
#   -x "#{e|+:#{popup_pane_left},#{cursor_x}}" \
#   -y "#{?#{e|<:#{cursor_y},#{e|-:#{e|-:#{client_height},#{popup_pane_top}},1}},#{e|+:#{e|+:#{popup_pane_top},#{cursor_y}},1},#{e|-:#{e|-:#{e|+:#{popup_pane_top},#{cursor_y}},#{popup_height}},1}}" \
#   'rime-cli --exec "tmux send-keys {key}"'

bind-key h run-shell -b "tmux display-popup -E -w 80% -h 80% -b rounded 'lazydeck /process/#{pane_pid}'"

# -- navigation ----------------------------------------------------------------

bind C-t new-window -c "#{pane_current_path}"

unbind '"'
unbind %
bind n splitw -h -c '#{pane_current_path}'
bind - splitw -c '#{pane_current_path}'

# pane navigation
bind j select-pane -L  # move left
bind k select-pane -D  # move down
bind i select-pane -U  # move up
bind l select-pane -R  # move right
bind J "select-pane -m; select-pane -L; swap-pane; select-pane -L; select-pane -M"
bind K "select-pane -m; select-pane -D; swap-pane; select-pane -D; select-pane -M"
bind I "select-pane -m; select-pane -U; swap-pane; select-pane -U; select-pane -M"
bind L "select-pane -m; select-pane -R; swap-pane; select-pane -R; select-pane -M"

bind -n M-j select-pane -L  # move left
bind -n M-k select-pane -D  # move down
bind -n M-i select-pane -U  # move up
bind -n M-l select-pane -R  # move right
bind -n M-J "select-pane -m; select-pane -L; swap-pane; select-pane -L; select-pane -M"
bind -n M-K "select-pane -m; select-pane -D; swap-pane; select-pane -D; select-pane -M"
bind -n M-I "select-pane -m; select-pane -U; swap-pane; select-pane -U; select-pane -M"
bind -n M-L "select-pane -m; select-pane -R; swap-pane; select-pane -R; select-pane -M"
bind -n M-n splitw -h -c '#{pane_current_path}'

bind -r C-j previous-window # select previous window
bind -r C-l next-window     # select next window
bind C-S-j swap-window -t -1 \; select-window -t -1  # swap current window with the previous one
bind C-S-l swap-window -t +1 \; select-window -t +1  # swap current window with the next one

# -- copy mode -----------------------------------------------------------------

bind Enter copy-mode # enter copy mode

bind p paste-buffer

bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi C-v send -X rectangle-toggle
bind -T copy-mode-vi y send -X copy-selection
bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-selection
bind -T copy-mode-vi Escape send -X cancel
bind -T copy-mode-vi Home send -X start-of-line
bind -T copy-mode-vi End send -X end-of-line
bind -T copy-mode-vi i send-keys -X previous-prompt # 跳到上一个prompt
bind -T copy-mode-vi k send-keys -X next-prompt # 跳到下一个prompt
bind -T copy-mode-vi PageUp send -X halfpage-up
bind -T copy-mode-vi PageDown send -X halfpage-down

# vim:ft=tmux
