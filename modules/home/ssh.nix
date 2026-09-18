{
  flake.homeModules.ssh.programs.ssh = {
    enable = true;

    # 不再使用旧版默认值，一律在 settings."*" 中显式声明
    enableDefaultConfig = false;

    settings = {
      "home.lubui.com" = {
        User = "urie";
      };

      "mac.mini" = {
        User = "urie";
      };

      "orange.pi" = {
        User = "orange.pi";
      };

      "rpi4" = {
        User = "urie";
        HostName = "raspberrypi.lan";
        ProxyJump = "home.lubui.com";
      };

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

      # 通配块由 home-manager 始终渲染在最后
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
}
