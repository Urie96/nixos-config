set -x SHELL_PID "$fish_pid"
argparse c/cmd= -- $argv
set -l chooser_cmd "$_flag_c"
set -l file_path "$argv"

#if [ -n "$YAZI_ID" ]
#    if [ -n "$file_path" ]
#        ya emit reveal "$file_path"
#    end
#    exit
#end

set -l bg_job (jobs | awk '$4=="yazi" {print $1;exit;}' )
if [ -n "$bg_job" ]
    fg "%$bg_job" 2>/dev/null
    commandline -f repaint
    return
end

if [ -z "$file_path" ]
    set file_path "$PWD"
end

set -x CWD_FILE (mktemp -t "yazi-cwd.XXXXX")

function __change_workdir --on-signal SIGUSR1 --inherit-variable CWD_FILE
    set -l cwd (cat -- "$CWD_FILE" 2>/dev/null)
    if [ -x "$cwd" ]
        cd -- "$cwd"
    end
    rm -f -- "$CWD_FILE"
end

if [ -n "$chooser_cmd" ]
    yazi --chooser-file="$CWD_FILE" "$file_path"
    set -l file (cat -- "$CWD_FILE")
    if [ -n "$file" ]
        "$chooser_cmd" "$file"
    end
    rm -f -- "$CWD_FILE"
    exit
else
    yazi --cwd-file="$CWD_FILE" "$file_path"
    __change_workdir
end
