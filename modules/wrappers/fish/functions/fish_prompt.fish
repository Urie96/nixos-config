# ── OS icon (computed once, then cached in $prompt_os_icon) ──
if not set -q prompt_os_icon
    set -g prompt_os_icon ""
    if test (uname -o 2>/dev/null) = Android
        set prompt_os_icon (set_color A4C639)"  "
    else if test (uname -s) = Linux
        set prompt_os_icon (set_color 333333)" "
        set -l distro_id
        if test -f /etc/os-release
            set distro_id (string match -rg '^ID="?([^"[:space:]]+)"?' </etc/os-release)
        end
        switch $distro_id
            case arch
                set prompt_os_icon (set_color 1793D1)" "
            case centos
                set prompt_os_icon (set_color 932279)" "
            case debian
                set prompt_os_icon (set_color D70A53)" "
            case manjaro
                set prompt_os_icon (set_color 35BF5C)" "
            case nixos
                set prompt_os_icon (set_color 5277C3)" "
            case ubuntu
                set prompt_os_icon (set_color E95420)" "
        end
    else if test (uname -s) = Darwin
        set prompt_os_icon "󰀵 "
    end
end

#Save the return status and duration of the previous command
set -l last_pipestatus $pipestatus
set -lx __fish_last_status $status # Export for __fish_print_pipestatus.
set -l last_cmd_duration 0
if set -q CMD_DURATION
    set last_cmd_duration $CMD_DURATION
end

# ── Catppuccin Mocha palette ──
set -l white white
set -l crust 11111b
set -l red f38ba8
set -l maroon eba0ac
set -l peach fab387
set -l yellow f9e2af
set -l green a6e3a1
set -l sapphire 74c7ec
set -l lavender b4befe

# ═══════════════════════════════════════════
# Render prompt segments
# ═══════════════════════════════════════════

# ── Segment 1: OS + Hostname (red bg, crust fg) ──
echo -n (set_color $white)""(set_color $crust)(set_color -b $white)$prompt_os_icon
set -l ssh_prompt ""
if set -q SSH_CONNECTION
    set ssh_prompt "ssh://"
end
echo -n (set_color -b $red)(set_color $white)""(set_color -b $red)(set_color $crust)" $ssh_prompt"(prompt_hostname)

# ── Segment 2: Directory (peach bg, crust fg) ──
echo -n (set_color -b $peach)(set_color $red)""(set_color $crust)" "(prompt_pwd -d 3 -D 3)

# ── Segment 3: Git branch (yellow bg, crust fg) ──
set -l git_branch ""
if command git rev-parse --is-inside-work-tree &>/dev/null
    set git_branch (set_color $crust)"  "(command git symbolic-ref --short HEAD 2>/dev/null; or command git rev-parse --short HEAD 2>/dev/null)
end
echo -n (set_color -b $yellow)(set_color $peach)"$git_branch"

# ── Segment 4: Env Icon ──
set -l env_icon (set_color $crust)
set -q DIRENV_DIR && set env_icon $env_icon"(direnv)"
set -q NVIM && set env_icon $env_icon"(neovim)"
set -q DEVENV_ROOT && set env_icon $env_icon"(devenv)"
echo -n (set_color -b $green)(set_color $yellow)"$env_icon"

# ── Segment 5: Background jobs ──
set -l job_count_icon ""
set -l job_count (jobs | count)
if test $job_count -gt 0
    set job_count_icon (set_color $crust)"  $job_count "
end
echo -n (set_color -b $sapphire)(set_color $green)"$job_count_icon"

# ── Segment 6: Last command duration (lavender bg, crust fg) ──
set -l duration_text
if test $last_cmd_duration -lt 1000
    set duration_text "$last_cmd_duration""ms"
else if test $last_cmd_duration -lt 60000
    set duration_text (math --scale=1 "$last_cmd_duration / 1000")"s"
else if test $last_cmd_duration -lt 3600000
    set -l minutes (math --scale=0 "floor($last_cmd_duration / 60000)")
    set -l seconds (math --scale=0 "floor(($last_cmd_duration % 60000) / 1000)")
    set duration_text "$minutes""m""$seconds""s"
else
    set -l hours (math --scale=0 "floor($last_cmd_duration / 3600000)")
    set -l minutes (math --scale=0 "floor(($last_cmd_duration % 3600000) / 60000)")
    set -l seconds (math --scale=0 "floor(($last_cmd_duration % 60000) / 1000)")
    set duration_text "$hours""h""$minutes""m""$seconds""s"
end
echo -n (set_color -b $lavender)(set_color $sapphire)""(set_color $crust)"  $duration_text"

# ── End cap ──
set -l status_color (set_color $fish_color_status)
set -l statusb_color (set_color --bold $fish_color_status)
set -l pipestatus_string (__fish_print_pipestatus "[" "]" " | " "$status_color" "$statusb_color" $last_pipestatus)
echo -n (set_color normal)(set_color $lavender)" $pipestatus_string"(set_color normal)

# ── Second line: prompt character ──
echo
if test $__fish_last_status -eq 0
    set_color -o $green
else
    set_color -o $red
end
echo -n "❯ "(set_color normal)
