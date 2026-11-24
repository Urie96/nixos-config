#!/usr/bin/env bash

# `open` 会把调用方的环境原样交给 LaunchServices 拉起的 app。这条脚本通常是从 Tinycast
# 的自定义命令里调用的，而 Tinycast 自己可能是 home-manager 的 activate 脚本用 `open`
# 重启的 —— 那份环境里 PATH 是一串纯 nix store 路径（没有 /usr/bin），还带着 SUDO_* 之类。
# 漏进 kitty 之后，kitty 再 spawn 的东西（`kitten launch ... nvim`、以及 nvim 里的
# pbcopy provider）全都拿不到 /usr/bin/pbcopy，复制就静默不生效。
# 所以拉起 kitty 之前先清成 GUI 进程该有的最小环境。
env -i \
  HOME="$HOME" \
  USER="${USER:-$(id -un)}" \
  LOGNAME="${LOGNAME:-$(id -un)}" \
  PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  /usr/bin/open -a kitty

for ((i = 0; i < 10; i++)); do
  pid="$(lsappinfo info "net.kovidgoyal.kitty" | grep -Eo "pid = [0-9]*" | grep -Eo "[0-9]*")"
  kitty_socket="/tmp/mykitty-$pid"
  if [ ! -e "$kitty_socket" ]; then
    sleep 0.3
  else
    break
  fi
done

if [ "$#" -ne 0 ]; then
  # /Applications/kitty.app/Contents/MacOS/kitty @ --to "unix:$kitty_socket" launch --hold --type=tab fish -i -c '$argv' "$@"
  kitty @ --to "unix:$kitty_socket" launch --hold --type=tab "$@"
else
  kitty @ --to "unix:$kitty_socket" launch --hold --type=tab
fi
