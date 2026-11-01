{ self, ... }:
{
  perSystem =
    {
      mkDroidConfig,
      pkgs,
      inputs',
      self',
      ...
    }:
    {
      legacyPackages = {
        nixOnDroidConfigurations.default = mkDroidConfig {
          modules = [
            self.droidModules.full
            # 拉取式自动部署：会话（runit 起来之后）每 6 小时拉一次清单，
            # 不是自己就不动；不一致就 `nix copy` 拉闭包并跑新 generation 的 activate。
            self.droidModules.pull-deploy
            ({
              my.mainUser.name = "nix-on-droid";
              pullDeploy = {
                enable = true;
                machine = "nix-on-droid";
              };
            })
          ];
        };
      };
    };
}
