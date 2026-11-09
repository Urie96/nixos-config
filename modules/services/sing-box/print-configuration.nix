{
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      inputs',
      ...
    }:
    {
      packages.singbox-configuration = pkgs.writeShellApplication {
        name = "singbox-configuration";
        runtimeInputs = [
          inputs'.clan-core.packages.default
          pkgs.jq
          pkgs.qrencode
        ];
        meta.mainProgram = "singbox-configuration";
        text = ''
          if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
            echo "Usage: singbox-configuration [profile-name]"
            echo "  profile-name: 二维码里的 profile 名，默认 home"
            echo "  QR_TYPE=ASCII 可切换 qrencode 输出类型（默认 ANSIUTF8）"
            exit 0
          fi

          token=$(clan vars get --flake ${self.outPath} home-server singbox-android-subscription/token)
          if [ -z "$token" ]; then
            echo "failed to read singbox-android-subscription/token" >&2
            exit 1
          fi

          url="https://singbox.lubui.com/android/$token/config.json"
          name="''${1:-home}"
          link="sing-box://import-remote-profile?url=$(jq -rn --arg u "$url" '$u|@uri')#$(jq -rn --arg n "$name" '$n|@uri')"

          echo "URL: $url"
          echo
          qrencode -t "''${QR_TYPE:-ANSIUTF8}" "$link"
        '';
      };
    };
}
