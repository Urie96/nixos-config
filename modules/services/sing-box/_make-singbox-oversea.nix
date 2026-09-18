name:
{ config, ... }:
let
  sing-box-vars = config.clan.core.vars.generators.${name}.files;
  remote_domain = sing-box-vars.remote_domain.value;
in
{
  services.sing-box = {
    enable = true;
    settings = {
      inbounds = [
        {
          type = "vmess";
          tag = "vmess-in";
          listen = "::";
          listen_port = 8443;
          users = [
            {
              name = "urie";
              uuid._secret = sing-box-vars.uuid.path;
              alterId = 0;
            }
          ];
          tls = {
            enabled = true;
            certificate = [ sing-box-vars.crt.value ];
            key_path = sing-box-vars.key.path;
            server_name = remote_domain;
          };

          transport = {
            type = "ws";
            path = "/Dacexo5f/";
            headers = {
              Host = remote_domain;
            };
          };
          multiplex = {
            enabled = true;
          };
        }
      ];
      outbounds = [
        {
          type = "direct";
          tag = "direct";
        }
      ];
      route = {
        rules = [
          {
            inbound = "vmess-in";
            outbound = "direct";
          }
        ];
      };
      log = {
        disabled = false;
        level = "warn";
        timestamp = true;
      };
    };
  };
}
