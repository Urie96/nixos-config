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
}
