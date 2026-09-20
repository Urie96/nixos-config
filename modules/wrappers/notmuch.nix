{
  flake.wrappers.notmuch =
    { wlib, ... }:
    {
      imports = [ wlib.wrapperModules.notmuch ];

      # 内容对照 ~/.config/notmuch/default/config。
      # 相对路径由 notmuch 按 $HOME 展开，所以 "mail" == ~/mail
      # （macOS 大小写不敏感，等价于 ~/Mail）。
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
