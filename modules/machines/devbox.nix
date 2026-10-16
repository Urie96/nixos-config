{ self, ... }:
{
  perSystem =
    {
      mkSystemManagerConfig,
      ...
    }:
    {
      legacyPackages.systemConfigs.devbox = mkSystemManagerConfig {
        modules = [
          self.sysModules.full
          self.sysModules.harmonia
          self.sysModules.niks3
          (
            { pkgs, ... }:
            let
              username = "yangrui.0";
              home = "/home/${username}";
            in
            {
              my.mainUser.name = username;
              home-manager.users.${username}.programs.ssh.settings."code.byted.org" = {
                IdentityFile = "~/.ssh/id_ed25519";
                IdentitiesOnly = "yes";
                User = "git";
              };

              services.niks3 = {
                enable = true;
                httpAddr = "127.0.0.1:5751";
                s3 = {
                  endpoint = "tos-s3-cn-north.byted.org";
                  bucket = "niks3";
                  region = "china-north"; # R2 需要；AWS 填 us-east-1 之类
                  accessKeyFile = "/var/lib/niks3/access-key";
                  secretKeyFile = "/var/lib/niks3/secret-key";
                };
                apiTokenFile = "/var/lib/niks3/api-token";
                signKeyFiles = [ "/var/lib/niks3/signing-key" ];
              };

            }
          )
        ];
      };
    };
}
