{
  flake.wrappers.yazi =
    { pkgs, ... }:
    {
      settings.keymap = {
        mgr = {
          prepend_keymap = [
            {
              on = [ "+" ];
              run = "plugin zoom 1";
              desc = "Zoom in hovered file";
            }
            {
              on = [ "-" ];
              run = "plugin zoom -1";
              desc = "Zoom out hovered file";
            }
            {
              on = [ "<C-/>" ];
              run = "shell '$SHELL' --block";
              desc = "Open shell here";
            }
            {
              on = [ "<C-i>" ];
              run = "forward";
              desc = "Go forward to the next directory";
            }
            {
              on = [ "<C-j>" ];
              run = "tab_switch -1 --relative";
              desc = "Switch to the previous tab";
            }
            {
              on = [ "<C-l>" ];
              run = "tab_switch 1 --relative";
              desc = "Switch to the next tab";
            }
            {
              on = [ "<C-o>" ];
              run = "back";
              desc = "Go back to the previous directory";
            }
            {
              on = [ "<C-s>" ];
              run = "search --via=rg";
              desc = "Search files by content using ripgrep";
            }
            {
              on = [
                "f"
                "d"
              ];
              run = "search --via=fd";
              desc = "Search files by name using fd";
            }
            {
              on = [ "<PageDown>" ];
              run = "seek 5";
              desc = "Peek down 5 units in the preview";
            }
            {
              on = [ "<PageUp>" ];
              run = "seek -5";
              desc = "Peek up 5 units in the preview";
            }
            {
              on = [ "<Tab>" ];
              run = "tab_create --current";
              desc = "Create a new tab using the current path";
            }
            {
              on = [ "?" ];
              run = "help";
              desc = "Open help";
            }
            {
              on = [
                "D"
                "D"
              ];
              run = [
                "remove --permanently"
                "escape --visual --select"
              ];
              desc = "Permanently delete the files";
            }
            {
              on = [ "I" ];
              run = "shell '${pkgs.writeShellScript "init-dev" (builtins.readFile ./scripts/init-dev)}' --block";
              desc = "Init development env";
            }
            {
              on = [ "M" ];
              run = "plugin mount";
            }
            {
              on = [ "Z" ];
              run = "plugin fzf";
              desc = "Jump to a file/directory via fzf";
            }
            {
              on = [ "a" ];
              run = "rename";
              desc = "Rename a file or directory";
            }
            {
              on = [
                "b"
                "n"
              ];
              run = "create";
            }
            {
              on = [
                "c"
                "m"
              ];
              run = "plugin chmod";
              desc = "Chmod on selected files";
            }
            {
              on = [
                "c"
                "o"
              ];
              run = "shell 'sudo chown -R \"$(whoami)\" %h' --block";
            }
            {
              on = [
                "c"
                "x"
              ];
              run = [
                "shell 'chmod u+x %s' --block"
                "escape --visual --select"
              ];
            }
            {
              on = [
                "c"
                "a"
              ];
              run = [ "shell '~/dotfile/add_file %s' --block" ];
            }
            {
              on = [
                "c"
                "A"
              ];
              run = [ "shell '~/dotfile/add_file --encrypt %s' --block" ];
            }
            {
              on = [
                "d"
                "!"
              ];
              run = [
                "shell 'sudo rm -rf %s' --block"
                "escape --visual --select"
              ];
              desc = "sudo delete the files";
            }
            {
              on = [
                "d"
                "D"
              ];
              run = [
                "remove --force"
                "escape --visual --select"
              ];
              desc = "Move the files to the trash";
            }
            {
              on = [
                "d"
                "d"
              ];
              run = [
                "yank --cut"
                "escape --visual --select"
              ];
              desc = "Cut the selected files";
            }
            {
              on = [
                "d"
                "f"
              ];
              run = [
                "shell 'DELTA_FEATURES=+side-by-side delta %s --paging always' --block"
                "escape --visual --select"
              ];
              desc = "Diff the files";
            }
            {
              on = [
                "d"
                "l"
              ];
              run = "shell '${pkgs.writeShellScript "yazi-unlink-symlink" ''
                for file in "$@"; do
                  real="$(realpath "$file")"
                  mv "$file" "$file".bak
                  cp -r "$real" "$file"
                  chmod -R +w "$file"
                done
              ''} %s' --block";
              desc = "Unlink symbol link";
            }
            {
              on = [
                "d"
                "u"
              ];
              run = "shell 'du %h -h -d 1; read' --block";
            }
            {
              on = [
                "f"
                "f"
              ];
              run = "filter --smart";
              desc = "Filter the files";
            }
            {
              on = [
                "f"
                "p"
              ];
              run = "plugin toggle-pane max-preview";
              desc = "Maximize or restore the preview pane";
            }
            {
              on = [
                "g"
                "."
              ];
              run = "shell '${pkgs.writeShellScript "yazi-jump-project-root" ''
                root="$(find-project-root)"
                if [ -n "$root" ]; then
                  ya emit cd "$root"
                fi
              ''}'";
              desc = "Jump to project root";
            }
            {
              on = [
                "g"
                "r"
              ];
              run = "cd /";
            }
            {
              on = [
                "g"
                "s"
                "h"
              ];
              run = "cd sftp://home";
            }
            {
              on = [
                "g"
                "s"
                "m"
              ];
              run = "cd sftp://mac";
            }
            {
              on = [
                "g"
                "s"
                "k"
              ];
              run = "cd sftp://kindle";
            }
            {
              on = [
                "g"
                "s"
                "t"
              ];
              run = "cd sftp://termux";
            }
            {
              on = [
                "g"
                "t"
              ];
              run = ''shell 'ya emit cd "''${TMPDIR:-/tmp}"' '';
              desc = "Jump to temp dir";
            }
            {
              on = [ "i" ];
              run = "spot";
              desc = "Spot hovered file";
            }
            {
              on = [
                "j"
                "l"
              ];
              run = "follow";
              desc = "Jump symbol link";
            }
            {
              on = [
                "k"
                "r"
              ];
              run = "shell 'slim-kitten @ kitten remote.py pull %s' --block";
              desc = "Receive this remote files via rsync";
            }
            {
              on = [
                "k"
                "s"
              ];
              run = "shell 'slim-kitten @ kitten remote.py push \"$PWD\"' --block";
              desc = "Send local files to this remote directory via rsync";
            }
            {
              on = [
                "l"
                "g"
              ];
              run = "shell 'lazygit' --block";
            }
            {
              on = [
                "l"
                "m"
              ];
              run = "linemode mime";
              desc = "Linemode: mime";
            }
            {
              on = [
                "l"
                "n"
              ];
              run = "linemode none";
              desc = "Linemode: none";
            }
            {
              on = [
                "l"
                "p"
              ];
              run = "linemode permissions";
              desc = "Linemode: permissions";
            }
            {
              on = [
                "l"
                "s"
              ];
              run = "linemode size";
              desc = "Linemode: size";
            }
            {
              on = [
                "l"
                "t"
              ];
              run = "linemode mtime";
              desc = "Linemode: mtime";
            }
            {
              on = [
                "m"
                "a"
              ];
              run = "plugin yamb save";
              desc = "Save current position as a bookmark";
            }
            {
              on = [
                "m"
                "d"
              ];
              run = "plugin yamb delete_by_key";
              desc = "Delete a bookmark";
            }
            {
              on = [
                "m"
                "k"
              ];
              run = "create --dir";
              desc = "Create directory";
            }
            {
              on = [
                "m"
                "m"
              ];
              run = "plugin yamb jump_by_key";
              desc = "Jump to a bookmark";
            }
            {
              on = [
                "o"
                "A"
              ];
              run = "sort alphabetical --reverse --dir-first";
              desc = "Sort alphabetically (reverse)";
            }
            {
              on = [
                "o"
                "N"
              ];
              run = "sort natural --reverse --dir-first";
              desc = "Sort naturally (reverse)";
            }
            {
              on = [
                "o"
                "S"
              ];
              run = "sort size --reverse --dir-first";
              desc = "Sort by size (reverse)";
            }
            {
              on = [
                "o"
                "T"
              ];
              run = "sort mtime --reverse --dir-first";
              desc = "Sort by modified time (reverse)";
            }
            {
              on = [
                "o"
                "a"
              ];
              run = "sort alphabetical --reverse=no --dir-first";
              desc = "Sort alphabetically";
            }
            {
              on = [
                "o"
                "n"
              ];
              run = "sort natural --reverse=no --dir-first";
              desc = "Sort naturally";
            }
            {
              on = [
                "o"
                "s"
              ];
              run = "sort size --reverse=no --dir-first";
              desc = "Sort by size";
            }
            {
              on = [
                "o"
                "t"
              ];
              run = "sort mtime --reverse=no --dir-first";
              desc = "Sort by modified time";
            }
            {
              on = [
                "p"
                "L"
              ];
              run = "link";
              desc = "Symlink the absolute path of files";
            }
            {
              on = [
                "p"
                "P"
              ];
              run = "paste --force";
              desc = "Paste the files (overwrite if the destination exists)";
            }
            {
              on = [
                "p"
                "a"
              ];
              run = [
                "shell 'adb_tools push --sync %s /data/local/tmp\"' --block"
                "escape --visual --select"
              ];
            }
            {
              on = [
                "p"
                "f"
              ];
              run = "shell 'cb paste' --block";
              desc = "Paste the files from system clipboard";
            }
            {
              on = [
                "p"
                "l"
              ];
              run = "link --relative";
              desc = "Symlink the relative path of files";
            }
            {
              on = [
                "p"
                "p"
              ];
              run = "paste";
              desc = "Paste the files";
            }
            {
              on = [ "r" ];
              run = "open --interactive";
              # run = "shell '${pkgs.writeShellScript "open-file" (builtins.readFile ./open-file)} -s %s' --block";
              desc = "Open the selected files interactively";
            }
            {
              on = [
                "s"
                "c"
              ];
              run = "search --via=rg";
              desc = "Search files by content using ripgrep";
            }
            {
              on = [
                "s"
                "f"
              ];
              run = "search --via=fd";
              desc = "Search files by name using fd";
            }
            {
              on = [
                "s"
                "h"
              ];
              run = "shell '$SHELL' --block";
              desc = "Open shell here";
            }
            {
              on = [
                "s"
                "u"
              ];
              run = "shell 'sudo -E yazi %h' --block";
              desc = "Sudo yazi";
            }
            {
              on = [
                "u"
                "m"
              ];
              run = "shell 'umount %h' --block";
            }
            {
              on = [
                "v"
                "i"
              ];
              run = "shell \"nvim \" --block --interactive";
            }
            {
              on = [
                "y"
                "c"
              ];
              run = [
                "shell 'cat %h | cb copy' --block"
                "escape --visual --select"
              ];
              desc = "Copy the selected file's content";
            }
            {
              on = [
                "y"
                "d"
              ];
              run = "copy dirname";
              desc = "Copy the path of the parent directory";
            }
            {
              on = [
                "y"
                "f"
              ];
              run = [
                "shell 'cb copy %s' --block"
                "escape --visual --select"
              ];
              desc = "Copy the selected file's ref";
            }
            {
              on = [
                "y"
                "n"
              ];
              run = "copy filename";
              desc = "Copy the name of the file";
            }
            {
              on = [
                "y"
                "p"
              ];
              run = "copy path";
              desc = "Copy the absolute path";
            }
            {
              on = [
                "y"
                "y"
              ];
              run = [
                "yank"
                "escape --visual --select"
              ];
              desc = "Copy the selected files";
            }
            {
              on = [
                "z"
                "<Space>"
              ];
              run = "plugin zoxide";
              desc = "Jump to a directory via zoxide";
            }
            {
              on = [
                "z"
                "p"
              ];
              run = [
                "shell '${pkgs.writeShellScript "zip-file" (builtins.readFile ./scripts/zip-file)} %s' --block"
                "escape --visual --select"
              ];
            }
            {
              on = [
                "z"
                "t"
              ];
              run = [
                "shell 'tar -czvf tmp.tar.gz %s' --block"
                "escape --visual --select"
              ];
            }
          ];
        };

        cmp = {
          prepend_keymap = [
            {
              on = [ "?" ];
              run = "help";
              desc = "Open help";
            }
          ];
        };

        help = {
          prepend_keymap = [
            {
              on = [ "/" ];
              run = "filter";
              desc = "Apply a filter for the help items";
            }
            {
              on = [ "<Down>" ];
              run = "arrow 1";
              desc = "Move cursor down";
            }
            {
              on = [ "<Esc>" ];
              run = "escape";
              desc = "Clear the filter, or hide the help";
            }
            {
              on = [ "<Up>" ];
              run = "arrow -1";
              desc = "Move cursor up";
            }
            {
              on = [ "q" ];
              run = "close";
              desc = "Exit the process";
            }
          ];
        };

        input = {
          prepend_keymap = [
            {
              on = [ "<Esc>" ];
              run = "close";
              desc = "Cancel input";
            }
            {
              on = [ "?" ];
              run = "help";
              desc = "Open help";
            }
          ];
        };

        pick = {
          prepend_keymap = [
            {
              on = [ "?" ];
              run = "help";
              desc = "Open help";
            }
          ];
        };

        tasks = {
          prepend_keymap = [
            {
              on = [ "?" ];
              run = "help";
              desc = "Open help";
            }
            {
              on = [ "q" ];
              run = "close";
              desc = "Hide the task manager";
            }
          ];
        };
      };
    };
}
