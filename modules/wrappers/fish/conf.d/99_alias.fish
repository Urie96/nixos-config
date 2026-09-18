# Abbreviations
abbr --add -- - 'cd -'
abbr --add -- .. 'cd ..'
abbr --add -- l lazydeck
abbr --add --position anywhere --set-cursor -- A '| awk '\''{print $2%}'\'''
abbr --add --position anywhere --set-cursor -- P '| pv -q -L 3%k |'
abbr --add --position anywhere -- X '| xargs -I {}'
abbr --add -- brewi 'brew install'
abbr --add -- brewl 'brew list'
abbr --add -- brews 'brew search'
abbr --add -- brewu 'brew uninstall'
abbr --add -- buni 'bun i -g'
abbr --add -- bunl 'bun pm ls -g'
abbr --add -- bunu 'bun rm -g'
abbr --add -- cari 'cargo install'
abbr --add -- carl 'cargo install --list'
abbr --add -- cars 'cargo search'
abbr --add -- caru 'cargo uninstall'
abbr --add -- cc claude
abbr --add -- dc docker-compose
abbr --add -- dd 'dd status=progress if=/dev/null of=/dev/null'
abbr --add -- gc 'git clone'
abbr --add -- gc1 'git clone --depth=1'
abbr --add -- goi 'go install'
abbr --add -- gs 'git log --all -p -S'
abbr --add -- j just
abbr --add -- lg lazygit
abbr --add -- ll 'ls --color=always -hal'
abbr --add -- ls 'ls --color=always -h'
abbr --add -- nixs nix-search
abbr --add -- npmi 'npm i -g'
abbr --add -- npml 'npm ls -g'
abbr --add -- npmu 'npm un -g'
abbr --add -- pipi 'pip install'
abbr --add -- pipl 'pip list'
abbr --add -- pips 'python -m pip search'
abbr --add -- pipu 'pip uninstall'
abbr --add -- reload 'exec $SHELL -l'
abbr --add -- rsync 'rsync -auEzhv --mkpath --progress'
abbr --add -- tldr 'tldr -o'
abbr --add -- vi nvim
abbr --add -- which 'type -a'
# pi coding agent
abbr --add -- pid 'pi --model deepseek/deepseek-v4-pro --models deepseek/deepseek-v4-pro,deepseek/deepseek-v4-flash'

# Aliases
alias gitignore 'curl -sL https://www.gitignore.io/api/$argv'
