if test (count $argv) -eq 0
    echo "Usage: nixsh <package1> [package2...]"
    return 1
end

set -l packages
for pkg in $argv
    set -a packages "nixpkgs#$pkg"
end

nix shell --extra-experimental-features "nix-command flakes" $packages -c fish
