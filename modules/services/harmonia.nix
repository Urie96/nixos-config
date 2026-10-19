{ self, ... }:
{
  flake.nixosModules.harmonia =
    { config, pkgs, ... }:
    {
      # 共享签名 key（nix-signing）：下面 signKeyPaths 会用它给 narinfo 签名，
      # 所以这台机器也要声明那个 generator。模块自带 key，重复 import 会被去重。
      imports = [ self.nixosModules.nix-signing ];

      # 旧缓存 key，只为过渡期兼容历史保留；等所有消费该缓存的机器都信任
      # cache.lubui.com-1 后，这个 generator（连同 vars 里的值）就可以删了。
      clan.core.vars.generators.harmonia = {
        files."harmonia.secret" = { };
        files."harmonia.pub".secret = false;
        runtimeInputs = with pkgs; [ nix ];
        script = ''
          nix-store --generate-binary-cache-key cache.lubui.com-2 $out/harmonia.secret $out/harmonia.pub
        '';
      };

      # signKeyPaths 可以给多把 key：harmonia 会给每把 key 各写一行 `Sig:`，
      # 客户端只要信任其中任意一把就能验过（nix 的 checkSignatures 是「任一签名
      # 有效即通过」）。所以过渡期两把同时签：
      #   - cache.lubui.com-2（旧缓存 key）：还没信任新公钥的客户端靠它兼容历史；
      #   - cache.lubui.com-1（共享签名 key）：三台构建机也用它签构建产物。
      services.harmonia.cache = {
        enable = true;
        signKeyPaths = [
          config.clan.core.vars.generators.harmonia.files."harmonia.secret".path
          config.clan.core.vars.generators.nix-signing.files."nix-signing.secret".path
        ];
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
    { config, ... }:
    let
      harmoniaModulePath = "${self.inputs.nixpkgs.outPath}/nixos/modules/services/networking/harmonia.nix";
    in
    {
      imports = [ harmoniaModulePath ];

      sops.secrets.nix-sign = { };

      services.harmonia.cache = {
        enable = true;
        signKeyPaths = [ config.sops.secrets.nix-sign.path ];
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
