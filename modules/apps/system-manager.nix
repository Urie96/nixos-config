{
  perSystem =
    {
      pkgs,
      system,
      self',
      inputs',
      ...
    }:
    {
      apps.system-manager = {
        type = "app";
        meta.description = "在当前主机上运行 system-manager switch（macOS / 非 NixOS 主机用）";
        program = "${pkgs.writeShellScript "system-manager" ''
          set -x
          export PATH=${
            pkgs.lib.makeBinPath [
              pkgs.gitMinimal
              pkgs.coreutils
              pkgs.findutils
              pkgs.jq
              pkgs.unixtools.hostname
              pkgs.nixVersions.latest
              inputs'.system-manager.packages.default
            ]
          }:/usr/bin:/usr/sbin:/bin
          profile="$(hostname)"

          system-manager switch --flake .#"$profile" --sudo
        ''}";
      };

    };
}
