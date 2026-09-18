fish_default_key_bindings

# bind -M insert \cA beginning-of-line # ctrl-a
# bind -M insert \cE end-of-line # ctrl-e
bind \e\x7F backward-kill-path-component # alt-backspace to delete word

function _resume_background_jobs
    set -l jobs_output (jobs | string collect)
    if [ -z "$jobs_output" ]
        printf "No background jobs\n\n"
    else
        set -l selected (echo "$jobs_output" | fzf --prompt 'Background Jobs> ' --bind one:accept --bind ctrl-z:abort | awk '{print $1;exit;}')
        if [ -n "$selected" ]
            fg "%$selected" 2>/dev/null
        end
    end
    commandline -f repaint
end

bind \cZ _resume_background_jobs
bind \cg edit_command_buffer

function _command_line_ls
    if [ -z (commandline -b) ]
        commandline -r r
        commandline -f execute
    else
        set -x CWD_FILE (mktemp -t "yazi-cwd.XXXXX")
        yazi --chooser-file="$CWD_FILE"
        set -l selected (cat -- "$CWD_FILE")
        for i in $selected
            commandline -i (realpath -s --relative-to=. "$i")' '
        end

        commandline -f repaint
    end
end

bind \cr _command_line_ls

bind up fzf-history-widget
