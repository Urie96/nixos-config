{
  flake.nixosModules.base-image =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        parted
        gitMinimal
        curl
        mtdutils
      ];

      time.timeZone = "Asia/Shanghai";

      # Root 用户的密码和 SSH 密钥。如果网络配置有误，可以用此处的密码在控制台上登录进去手动调整网络配置。
      users.mutableUsers = false;
      users.users.root = {
        password = "urie";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILngYCsNBe3TMnnpOaxTnVoOCsJq1hq+ge5pYARiNWCC lubui.com@gmail.com"
        ];
      };

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = true;
          PermitRootLogin = lib.mkForce "prohibit-password";
        };
        openFirewall = true;
      };

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };

      system.stateVersion = config.system.nixos.release;
    };
}
