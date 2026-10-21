{
  flake.nixosModules.acme =
    {
      config,
      pkgs,
      lib,
      inputs',
      self',
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
      packages = self'.packages;
    in
    {
      clan.core.vars.generators.tencent_cloud = {
        files.acme_dns_api_env = { };
        prompts.secret_id = { };
        prompts.secret_key = { };
        script = ''
          echo "TENCENTCLOUD_SECRET_ID=$(cat $prompts/secret_id)" >> $out/acme_dns_api_env
          echo "TENCENTCLOUD_SECRET_KEY=$(cat $prompts/secret_key)" >> $out/acme_dns_api_env
        '';
      };

      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "lubui.com@gmail.com";
          environmentFile = config.clan.core.vars.generators.tencent_cloud.files.acme_dns_api_env.path;
          dnsResolver = "223.5.5.5";
          extraLegoFlags = [
            "--dns.propagation.wait"
            "1m"
          ];
        };
        certs."lubui.com" = {
          group = config.services.nginx.group; # for nginx reading cert
          dnsProvider = "tencentcloud";
          # 注意：不要在这里重复主域名 lubui.com。lego 会用 `-d lubui.com -d lubui.com
          # -d *.lubui.com` 请求，而签发出来的证书只有 2 个 SAN，配合 nixpkgs 默认加的
          # `--force-cert-domains`，lego 每次都判定「domains 数量不一致 = 配置变更」并强制
          # 续期，导致每日定时器跑一次就真续一次证书。
          extraDomainNames = [
            "*.lubui.com"
          ];
          reloadServices = [ "nginx" ];
          # validMinDays = 90; # for test renew
          postRun = ''
            echo "SSL 证书更新成功"
            DOMAIN_KEYWORD=lubui.com CERT_PRIVATE_KEY="$(cat key.pem)" CERT_PUBLIC_KEY="$(cat fullchain.pem)" ${nur.tencent-cloud-update-ssl}/bin/tencent_cloud_update_ssl
            ${lib.getExe packages.notify-me} -t "SSL自动更新" "lubui.com证书已自动更新"
          '';
        };
      };
    };
}
