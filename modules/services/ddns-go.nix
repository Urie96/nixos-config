{
  flake.nixosModules.ddns-go =
    {
      config,
      pkgs,
      utils,
      ...
    }:
    let
      settings = {
        dnsconf = [
          {
            dns = {
              id = "348384";
              name = "dnspod";
              secret = {
                _secret = config.clan.core.vars.generators.ddns-go.files.secret.path;
              };
            };
            ipv4 = {
              domains = [
                "*.lubui.com"
                "*.home.lubui.com"
              ];
              enable = true;
              gettype = "url";
              url = "https://ddns.oray.com/checkip, https://ip.3322.net";
            };
          }
        ];
        webhook = {
          webhookurl = "http://localhost:3102?tag=me&title=域名更新成功&body=#{ipv4Domains}已解析为#{ipv4Addr}";
        };
      };
    in
    {
      users.users.ddns-go = {
        description = "ddns-go service user";
        isSystemUser = true;
        group = "ddns-go";
      };
      users.groups.ddns-go = { };

      clan.core.vars.generators.ddns-go = {
        files.secret.owner = "ddns-go";
        prompts.secret.description = "DNS secret for dnspod (ddns-go)";
        prompts.secret.type = "hidden";

        script = ''
          cat "$prompts/secret" > "$out/secret"
        '';
      };

      systemd.services.ddns-go = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = {
          DATADIR = "%S/ddns-go";
        };
        unitConfig = {
          Description = "ddns-go service";
        };
        serviceConfig = {
          TimeoutSec = "5min";
          ExecStart = "${pkgs.ddns-go}/bin/ddns-go -noweb -c /run/ddns-go/config.yaml";
          RestartSec = 30;
          User = "ddns-go";
          Group = "ddns-go";
          StateDirectory = "ddns-go";
          RuntimeDirectory = "ddns-go";
          RuntimeDirectoryMode = "0700";
          Restart = "on-failure";
        };
        preStart = ''
          ${utils.genJqSecretsReplacementSnippet settings "/run/ddns-go/config.yaml"}
        '';
      };
    };
}
