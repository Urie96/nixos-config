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
              # /etc/passwd 与 /etc/group 里的 uid/gid 是 nix-on-droid 在**构建机**上跑
              # `id -u` / `id -g` 生成出来的（inputs.nix-on-droid 的 modules/user.nix，
              # idsDerivation）。CI 在 home-server 构建（那里是 1000/100）时这份值就跟着
              # 走偏，设备真实 uid 10353 在 /etc/passwd 里查不到 → getpwuid() 返回 NULL，
              # `ssh` 直接以 "No user exists for uid 10353" 退出（`git push` 因此报
              # "could not read from remote repository"），`whoami` 也不认识自己。
              # 显式钉住本机的 Android app uid/gid（设备上 `id -u` / `id -g`）；重装 app
              # 后 Android 可能重新分配，届时跟着改这里。
              user.uid = 10353;
              user.gid = 10353;
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
