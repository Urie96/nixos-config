{
  flake.homeModules.ssh =
    {
      lib,
      osConfig,
      ...
    }:
    let
      # 家庭局域网内的主机只有在机器本身不在家庭网络时才需要经由
      # home.lubui.com 跳板访问。
      proxyJump = lib.optionalAttrs (!osConfig.my.homeNetwork) {
        ProxyJump = "home.lubui.com";
      };
    in
    {
      programs.ssh = {
        enable = true;

        # 不再使用旧版默认值，一律在 settings."*" 中显式声明
        enableDefaultConfig = false;

        settings = {
          "home.lubui.com" = {
            User = "urie";
          };

          "macmini" = {
            User = "urie";
            HostName = "macmini.lan";
          }
          // proxyJump;

          "orangepi" = {
            User = "urie";
            HostName = "orangepi5plus.lan";
          }
          // proxyJump;

          "rpi4" = {
            User = "urie";
            HostName = "raspberrypi.lan";
          }
          // proxyJump;

          "termux.lan" = {
            Port = 8022;
            User = "nix-on-droid";
          };

          "kindle.lan" = {
            Port = 2222;
            User = "root";
          };

          "devbox" = {
            User = "yangrui.0";
            HostName = "10.37.107.28";
          };

          "*" = {
            ForwardAgent = false;
            AddKeysToAgent = "no";
            Compression = false;
            ServerAliveInterval = 30;
            ServerAliveCountMax = 2;
            HashKnownHosts = false;
            UserKnownHostsFile = "~/.ssh/known_hosts";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/master-%r@%n:%p";
            ControlPersist = "yes";
          };
        };
      };
    };
}
