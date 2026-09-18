{
  flake.nixosModules.samba =
    { ... }:
    {
      services.samba = {
        enable = true;
        settings = {
          global = {
            "bind interfaces only" = "yes";
            "interfaces" = "lo enp2s0";
            # "hosts allow" = "192.168.1. 192.168.2. 127.0.0.1 localhost";
            # "hosts deny" = "0.0.0.0/0";
            "guest account" = "nobody";
            # "prefered master" = "yes";
            # https://serverfault.com/questions/827985/samba-nmbd-query-name-response-multiple-2-responses-received
            "local master" = "no";
            "domain master" = "no";
            "preferred master" = "no";
          };
          urie = {
            "valid users" = "urie"; # sudo smbpasswd -a urie
            "path" = "/home/urie";
            "public" = "yes";
            "browsable" = "yes";
            "writable" = "yes";
            "guest ok" = "no";
            "create mask" = "0644";
            "directory mask" = "0755";
          };
        };
      };
    };
}
