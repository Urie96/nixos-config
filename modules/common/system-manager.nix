{
  # https://system-manager.net/main/reference/all-options/
  flake.sysModules.common = {
    nix.enable = true;

    services.userborn.enable = true;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "bakeup";
    };

    environment.variables = {
      EDITOR = "nvim";
      MANPAGER = "nvim +Man!";
      HF_ENDPOINT = "https://hf-mirror.com";
    };

    # Enable and configure services
    services = {
      # nginx.enable = true;
    };

    environment = {
      systemPackages = [
      ];
    };

    # 让 sudo 能找到 Nix 路径（/run/current-system/sw/bin）
    security.sudo = {
      enable = true;
      extraConfig = ''
        Defaults secure_path="/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      '';
    };
  };
}
