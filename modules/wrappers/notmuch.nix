{
  flake.wrappers.notmuch =
    { wlib, pkgs, ... }:
    {
      imports = [ wlib.wrapperModules.notmuch ];

      package = pkgs.notmuch.override { withEmacs = false; };

      settings = {
        database = {
          path = "mail";
          mail_root = "mail";
        };

        user = {
          name = "Yang Rui";
          primary_email = "urie96@qq.com";
          other_email = "lubui.com@gmail.com;urie@mail.ustc.edu.cn;";
        };

        new.ignore = ".mbsyncstate;.uidvalidity";

        maildir.synchronize_flags = true;
      };
    };

  # 安装入口：modules/full.nix 里 `imports = with self.<class>; [ notmuch ]` 引用。
  # 通用的 install 模块只为声明 `wrappers.notmuch.*` 选项，真正落地靠 enable 打开。
  flake.nixosModules.notmuch = { wrappers.notmuch.enable = true; };
  flake.darwinModules.notmuch = { wrappers.notmuch.enable = true; };
  flake.sysModules.notmuch = { wrappers.notmuch.enable = true; };
}
