# Tinycast 的自定义命令（启动器里那一列 shell 命令），见 ./default.nix。
#
# 命令在这里用 Nix 写，再由模块序列化成 JSON 写进 UserDefaults —— 因为这条链路走不了
# settings.json：settings-file 的硬约束是「内容永不进文件」，自定义命令存在
# UserDefaults 的 `customCommands` 键下（一段 JSON Data），域是 bundle id
# `com.tinycast.app`。
#
# 每条命令的 `text` 就是脚本正文，内联在这里，不再有外部 .sh 文件：
#   - shebang 由 `writeShellApplication` 负责（绝对路径的 nix bash），所以正文里不要写；
#   - `runtimeInputs` 会被前置进脚本内的 PATH，正文里照旧写命令名；
#   - 参数由 App 以位置参数交给 zsh，正文里用 `$1` `$2` 取（值不会被拼进命令文本）；
#   - macOS 自带的 open/pbpaste/pbcopy/osascript/say 没有 nix 包，靠 `inheritPath` 从
#     /usr/bin 来；`~/bin` 里那几个私人工具（active-arc-tab、launch-terminal-tab、
#     adb-tools、fmt-file）以及 Hammerspoon 的 `hs`、last-download-path 同理，等它们
#     也 nix 化之后可以按脚本把 `inheritPath` 收掉。
#
# 字段名和默认值来自 Tinycast 的 Features/CustomCommands/Model/CustomCommand.swift：
# 解码只要求 `id` / `name` / `command`，其余都有默认值；参数是
# `{ name, isOptional }`，最多 3 个。
# 返回的是「默认命令表」：[{ name, text, runtimeInputs, arguments, showsOutput, ... }]。
# 模块（./default.nix）把它当 `my.tinycast.commands` 的默认值，再包成脚本、序列化成 JSON。
{ self, ... }:
{
  flake.homeModules.tinycast =
    {
      pkgs,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      nur = self.inputs.nur-packages.packages.${system} // self.packages.${system};

      opt = name: {
        inherit name;
        isOptional = true;
      };
    in
    {
      programs.tinycast.commands = [

        {
          name = "Copy From Termux";
          runtimeInputs = [ nur.adb-tools ];
          showsOutput = true;
          text = ''
            set -euo pipefail

            adb-tools clipboard-get
          '';
        }
        {
          name = "Paste To Termux";
          runtimeInputs = [ nur.adb-tools ];
          showsOutput = true;
          text = ''
            adb-tools clipboard-set "$(pbpaste)"
          '';
        }
        {
          name = "Create Timer";
          runtimeInputs = with pkgs; [
            coreutils
            nur.confetti
          ];
          arguments = [
            (opt "Hours")
            (opt "Minutes")
            (opt "Seconds")
          ];
          text = ''
            hours=''${1:-0}
            mins=''${2:-0}
            secs=''${3:-0}
            time=$((hours * 3600 + mins * 60 + secs))

            notify() {
              /usr/bin/osascript -e "display notification \"$2\" with title \"$1\""
            }

            notify "Timer Start" "''${hours} Hours ''${mins} Minutes ''${secs} Seconds"
            sleep "$time"
            confetti
            notify "Timer Complete" "''${hours} Hours ''${mins} Minutes ''${secs} Seconds"
            say timer complete
          '';
        }
        {
          name = "Paste PNG To File";
          runtimeInputs = with pkgs; [
            coreutils
            kitty
            pngpaste
            yazi
            nur.launch-terminal-tab
          ];
          text = ''
            dir="$HOME/Documents/pngpaste"
            mkdir -p "$dir"
            path="$dir/$(date "+%Y%m%d%H%M%S").png"
            pngpaste "$path"
            launch-terminal-tab yazi "$path"
            echo -n "$path"
          '';
        }
        {
          name = "Paste To Neovim";
          runtimeInputs = with pkgs; [
            kitty
            nur.launch-terminal-tab
            nur.neovim
          ];
          text = ''
            launch-terminal-tab sh -c "pbpaste | nvim -"
          '';
        }

        {
          name = "Toggle Mac Bar";
          text = ''
            osascript <<EOF
            tell application "System Events"
                if autohide menu bar of dock preferences then
                    set autohide menu bar of dock preferences to false
                    return "false"
                else
                    set autohide menu bar of dock preferences to true
                    return "true"
                end if
            end tell
            EOF
          '';
        }

      ];
    };
}
