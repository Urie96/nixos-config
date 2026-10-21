{ self, ... }:
{
  flake.sysModules.niks3-work = { config, ... }: {
    imports = [ self.sysModules.niks3 ];
    sops.secrets = {
      nix-sign.owner = "niks3";
      niks3-ak.owner = "niks3";
      niks3-sk.owner = "niks3";
      niks3-api-token.owner = "niks3";
    };

    services.niks3 = {
      enable = true;
      httpAddr = "0.0.0.0:5751";
      s3 = {
        endpoint = "tos-s3-cn-north.byted.org";
        bucket = "niks3";
        region = "china-north";
        accessKeyFile = config.sops.secrets.niks3-ak.path;
        secretKeyFile = config.sops.secrets.niks3-sk.path;
      };
      apiTokenFile = config.sops.secrets.niks3-api-token.path;
      signKeyFiles = [ config.sops.secrets.nix-sign.path ];
    };
  };
}
