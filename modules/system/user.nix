{
  flake.nixosModules.user =
    { config, ... }:
    let
      keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILngYCsNBe3TMnnpOaxTnVoOCsJq1hq+ge5pYARiNWCC lubui.com@gmail.com"
      ];
      username = config.my.mainUser.name;
    in
    {
      users.users = {
        ${username} = {
          isNormalUser = true;
          home = "/home/${username}";
          extraGroups = [
            "audio"
            "wheel"
            "docker"
            "plugdev"
            "vboxusers"
            "adbusers"
            "input"
            "kvm"
            "wireshark"
            "dialout"
          ];
          uid = 1000;
          openssh.authorizedKeys.keys = keys;
        };
      };

      services.getty.autologinUser = "${username}";

      boot.initrd.network.ssh.authorizedKeys = keys;

      security.sudo.wheelNeedsPassword = false;
    };

  flake.sysModules.user =
    { config, ... }:
    let
      username = config.my.mainUser.name;
    in
    {
      users.groups.${username} = { };

      users.users.${username} = {
        ignoreShellProgramCheck = true;
        group = username;
        isNormalUser = true;
      };
    };
}
