#!/usr/bin/env bash

open -a kitty

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
