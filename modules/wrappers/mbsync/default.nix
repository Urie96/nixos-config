{
  flake.wrappers.mbsync =
    # 本机账号。原先这份配置在 modules/home/dotConfig/isyncrc（软链到
    # ~/.config/isyncrc，正好是 isync 的 XDG 默认查找位置）；现在随 wrapper
    # 生成、用 `-c` 指过去，和 himalaya / notmuch / vdirsyncer 的配置放一起。
    # 账号和 modules/wrappers/himalaya.nix 里的一一对应，密码都从 rbw 取；
    # 本地邮件目录还是 ~/mail/<账号>/（maildirRoot 的默认值），notmuch 也指向它。
    {
      pkgs,
      ...
    }:
    {
      # PassCmd 跑的 `rbw` 要在 PATH 上；挂到 wrapper 上就不依赖系统里装没装 rbw。
      runtimePkgs = [ pkgs.rbw ];

      accounts = {
        gmail = {
          host = "imap.gmail.com";
          user = "lubui.com@gmail.com";
          passCmd = "rbw get 'gmail imap'";
        };

        qq = {
          host = "imap.qq.com";
          user = "urie96@qq.com";
          passCmd = "rbw get 'qq imap'";
        };

        ustc = {
          host = "mail.ustc.edu.cn";
          user = "urie@mail.ustc.edu.cn";
          passCmd = "rbw get 'ustc imap'";
        };
      };
    };
}
