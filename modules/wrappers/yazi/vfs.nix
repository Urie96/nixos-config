{
  flake.wrappers.yazi.settings.vfs = {
    sftp = {
      home = {
        type = "sftp";
        host = "home.lubui.com";
        user = "urie";
        port = 22;
        key_file = "~/.ssh/id_ed25519";
      };
      mac = {
        type = "sftp";
        host = "mac.mini";
        user = "urie";
        port = 22;
        key_file = "~/.ssh/id_ed25519";
      };
      kindle = {
        type = "sftp";
        host = "kindle.lan";
        user = "root";
        port = 2222;
        key_file = "~/.ssh/id_ed25519";
      };
      termux = {
        type = "sftp";
        host = "termux.lan";
        user = "u0_a356";
        port = 8022;
        key_file = "~/.ssh/id_ed25519";
      };
    };
  };
}
