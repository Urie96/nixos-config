{ self, ... }:
{
  flake.nixosModules.harmonia =
    { config, pkgs, ... }:
    {
      clan.core.vars.generators.harmonia = {
        files."harmonia.secret" = { };
        files."harmonia.pub".secret = false;
        runtimeInputs = with pkgs; [ nix ];
        script = ''
          nix-store --generate-binary-cache-key cache.lubui.com-2 $out/harmonia.secret $out/harmonia.pub
        '';
      };

      services.harmonia.cache = {
        enable = true;
        signKeyPaths = [ config.clan.core.vars.generators.harmonia.files."harmonia.secret".path ];
        settings = {
          priority = 30;
        };
      };

      services.nginx.virtualHosts."cache.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:5000";
          proxyWebsockets = true;
        };
      };
    };

  flake.sysModules.harmonia =
    let
      harmoniaModulePath = "${self.inputs.nixpkgs.outPath}/nixos/modules/services/networking/harmonia.nix";
      secret = "/var/lib/harmonia/harmonia.secret";
    in
    {
      imports = [ harmoniaModulePath ];

      services.harmonia.cache = {
        enable = true;
        signKeyPaths = [ secret ];
        settings.priority = 30;
      };

      # 私钥生成命令（生成后保留 pub，删除 secret 前记得备份）：
      #   sudo mkdir -p -m 0700 /var/lib/harmonia
      #   sudo nix-store --generate-binary-cache-key devbox-1 \
      #     /var/lib/harmonia/harmonia.secret /var/lib/harmonia/harmonia.pub
      # devbox 当前实际安装的公钥（其他机器拉取此缓存时信任它）：
      #   devbox-1:EHo6uXsF6SnbTmjmnB4CWua3VGrLeaI5PFVBPwkWPAE=
    };
}
