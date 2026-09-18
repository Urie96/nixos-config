function __fish_notify_bell --on-event fish_postexec
    if set -q fish_notify_bell_enabled; and test "$fish_notify_bell_enabled" = true
        if test (math $CMD_DURATION / 1000) -ge 5 # 超过5s的命令执行完毕需要响铃
            printf '\a'
        end
    end
end
