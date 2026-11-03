#!/usr/bin/env bash

adb() {
  if [[ -z "$ANDROID_SERIAL" ]]; then
    local ANDROID_SERIAL
    ANDROID_SERIAL="$(command adb devices -l | grep -E '\sdevice\s' | fzf --bind one:accept --exit-0 | awk '{print $1}')"
    export ANDROID_SERIAL
  fi
  command adb "$@"
}

adb-shell-termux() {
  local cmd
  cmd=$(
    cat <<'EOF'
export PATH=/data/data/com.termux/files/usr/bin:$PATH
export LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec-ld-preload.so
export LOGDIR=/data/data/com.termux/files/usr/var/log
export PREFIX=/data/data/com.termux/files/usr
export SVDIR=/data/data/com.termux/files/usr/var/service
export TMPDIR=/data/data/com.termux/files/usr/tmp

export TERMUX_VERSION=0.118.1
export TERMUX_MAIN_PACKAGE_FORMAT=debian

export HOME=/data/data/com.termux/files/home
export SHELL=/data/data/com.termux/files/usr/bin/fish

cd $HOME
$SHELL -l -i
EOF
  )

  adb shell -t exec run-as com.termux sh -c "$(printf "%q" "$cmd")"
}

ssh-over-adb() {
  adb forward tcp:8022 tcp:8022 >/dev/null 2>&1
  ssh nix-on-droid@127.0.0.1 -p 8022 "$@"
}

ssh-directly() {
  ssh nix-on-droid@termux.lan -p 8022 "$@"
}

try-ssh() {
  ssh-directly "$@"
}

clipboard-get() {
  curl -s -H "Authorization: Bearer $(rbw get shellbox_token)" http://termux.lan:16888/clipboard | jq -r .text
}

clipboard-set() {
  local text
  if (($# > 0)); then
    text="$*"
  else
    text="$(cat)"
  fi
  curl -s -X PUT -H "Authorization: Bearer $(rbw get shellbox_token)" -H "Content-Type: application/json" \
    --data "$(jq -n --arg text "$text" '{text: $text}')" \
    "http://termux.lan:16888/clipboard"
}

screenshot() {
  if [[ -t 1 ]]; then
    echo "adb-tools screenshot: stdout is a TTY; refusing to write screenshot binary data to terminal." >&2
    echo "Usage: adb-tools screenshot > screenshot.png" >&2
    exit 2
  fi

  try-ssh "sudo /system/bin/screencap -p"
}

usage() {
  cat <<'EOF'
Usage: adb-tools <command> [args...]

Commands:
  shell-termux                 Open an adb shell in Termux environment
  ssh-over-adb [args...]       Forward adb tcp:8022 and ssh to localhost:8022
  ssh-directly [args...]       SSH directly to configured Termux host
  clipboard-get                Print Android clipboard
  clipboard-set [text]         Set Android clipboard;
  screenshot                   Write Android screenshot binary data to stdout
  help                         Show this help
EOF
}

main() {
  local cmd="$1"
  [[ $# -gt 0 ]] && shift

  case "$cmd" in
  shell-termux | termux-shell)
    adb-shell-termux "$@"
    ;;
  ssh-over-adb)
    ssh-over-adb "$@"
    ;;
  ssh-directly)
    ssh-directly "$@"
    ;;
  clipboard-get | get)
    clipboard-get "$@"
    ;;
  clipboard-set | set)
    clipboard-set "$@"
    ;;
  screenshot)
    screenshot "$@"
    ;;
  help | -h | --help)
    usage
    ;;
  *)
    echo "adb-tools: unknown command: $cmd" >&2
    usage >&2
    exit 2
    ;;
  esac
}

main "$@"
