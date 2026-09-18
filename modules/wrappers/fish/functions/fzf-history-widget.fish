set -l -- command_line (commandline)
set -l -- current_line (commandline -L)
set -l -- total_lines (count $command_line)
set -l -- fzf_query (string escape -- $command_line[$current_line])

set -lx -- FZF_DEFAULT_OPTS (string join ' ' -- \
  '--bind="focus,multi,resize:bg-transform:if test \\"$FZF_COLUMNS\\" -gt 100 -a \\\\( \\"$FZF_SELECT_COUNT\\" -gt 0 -o \\\\( -z \\"$FZF_WRAP\\" -a (string join0 -- <{f3..} | string length) -gt (math $FZF_COLUMNS - (switch $FZF_WITH_NTH; case 2..; echo 13; case 1,3..; echo 25; case 3..; echo 1; end)) \\\\) -o (string split0 -- <{sf3..} | fish_indent | count) -gt 1 \\\\); echo show-preview; else; echo hide-preview; end"' \
  '--preview="test \\"$FZF_SELECT_COUNT\\" -gt 0; and string split0 -- <{+sf3..} | fish_indent (string match -q -- 3.\\\\* $version; or echo -- --only-indent) --ansi; and echo -n \\\\n; string collect -- \\\\#\\\\ {1} (string split0 -- <{sf3..}) | fish_indent --ansi"' \
  '--preview-window="right,50%,wrap-word,follow,info,hidden"' \
  "--height 40% --min-height=20+ --bind=ctrl-z:ignore" \
  $FZF_DEFAULT_OPTS \
  '--with-nth=3.. --nth=2..,.. --accept-nth=3.. --scheme=history' \
  '--no-wrap --wrap-sign="\t\t\t↳ " --preview-wrap-sign="↳ " --freeze-left=1' \
  '--bind="ctrl-t:change-with-nth(1,3..|3..)"' \
  '--bind="ctrl-d:execute-silent(eval builtin history delete -Ce -- (string escape -n -- (string split0 -- <{+sf3..})))+reload(eval $FZF_DEFAULT_COMMAND)"' \
  "--highlight-line --ansi" \
  ' --delimiter="\t" --tabstop=4 --read0 --print0 --with-shell='(status fish-path)\\ -c)

set -lx -- FZF_DEFAULT_COMMAND 'builtin history -z --color=always --show-time=(set_color $fish_color_comment 2>/dev/null; or set_color normal)"%F %T%t%s%t"(set_color normal)'

# Merge history from other sessions before searching
test -z "$fish_private_mode"; and builtin history merge

if set -l fzf_out (eval $FZF_DEFAULT_COMMAND \| fzf --expect=tab --query=$fzf_query | string split0)
    set -l fzf_key $fzf_out[1]
    set -l result $fzf_out[2..-1]
    if test "$total_lines" -eq 1
        commandline -- $result
    else
        set -l a (math $current_line - 1)
        set -l b (math $current_line + 1)
        commandline -- $command_line[1..$a] $result
        commandline -a -- '' $command_line[$b..-1]
    end
    # enter（空 key）→ 放入 prompt 并直接执行；tab → 只放入 prompt
    if test -z "$fzf_key"
        commandline -f execute
    end
end

commandline -f repaint
