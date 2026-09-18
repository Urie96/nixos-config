{
  flake.wrappers.himalaya =
    { wlib, ... }:
    {
      imports = [ wlib.wrapperModules.himalaya ];

      settings = {
        accounts = {
          gmail = {
            default = false;
            display-name = "lubui.com";
            email = "lubui.com@gmail.com";
            envelope.list.page-size = 50;
            imap.sasl.plain = {
              username = "lubui.com@gmail.com";
              password.command = "rbw get 'gmail imap'";
            };
            imap.server = "imaps://imap.gmail.com:993";
            mailbox.alias = {
              archive = "[Gmail]/All Mail";
              drafts = "[Gmail]/Drafts";
              inbox = "INBOX";
              sent = "[Gmail]/Sent Mail";
              trash = "[Gmail]/Trash";
            };
            smtp.sasl.plain = {
              username = "lubui.com@gmail.com";
              password.command = "rbw get 'gmail imap'";
            };
            smtp.server = "smtps://smtp.gmail.com:465";
          };
          qq = {
            default = false;
            display-name = "urie96";
            email = "urie96@qq.com";
            imap.sasl.plain = {
              username = "urie96@qq.com";
              password.command = "rbw get 'qq imap'";
            };
            imap.server = "imaps://imap.qq.com:993";
            smtp.sasl.plain = {
              username = "urie96@qq.com";
              password.command = "rbw get 'qq imap'";
            };
            smtp.server = "smtps://smtp.qq.com:465";
          };
          ustc = {
            default = true;
            display-name = "urie";
            email = "urie@mail.ustc.edu.cn";
            envelope.list.page-size = 50;
            # USTC runs Coremail, which supports no SASL at all: its pre-auth
            # CAPABILITY advertises no AUTH= mechanism and AUTHENTICATE PLAIN /
            # LOGIN both answer "NO AUTHENTICATE Not support mechanism".
            # himalaya's `imap.sasl.login` is the bare RFC 3501 `LOGIN` command,
            # the only mechanism that server accepts, so TLS is required (it is).
            imap.sasl.login = {
              username = "urie@mail.ustc.edu.cn";
              password.command = "rbw get 'ustc imap'";
            };
            imap.server = "imaps://mail.ustc.edu.cn:993";
            smtp.sasl.plain = {
              username = "urie@mail.ustc.edu.cn";
              password.command = "rbw get 'ustc imap'";
            };
            smtp.server = "smtps://mail.ustc.edu.cn:465";
          };
        };
        downloads-dir = "~/Downloads";
        envelope.list.page-size = 50;
        mailbox.alias.inbox = "INBOX";

      };
    };
}
