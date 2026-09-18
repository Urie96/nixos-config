{
  withSystem,
  self,
  config,
  ...
}:
{
  clan = {
    inherit self;
    pkgsForSystem = system: withSystem system ({ pkgs, ... }: pkgs);
    meta.name = "urie96";
    meta.description = "My selfhosted homelab";

    specialArgs = {
      inherit (config) flake;
    };

    inventory.instances = {
      urie-user = {
        module.name = "users";
        roles.default.extraModules = [ ];
        roles.default.tags.all = { };
        roles.default.settings = {
          user = "urie"; # (3)
          groups = [
            "wheel" # Allow using 'sudo'
            "networkmanager" # Allows to manage network connections.
            "video" # Allows to access video devices.
            "input" # Allows to access input devices.
            "audio"
            "docker"
            "plugdev"
            "vboxusers"
            "adbusers"
            "kvm"
            "wireshark"
            "dialout"
          ];
        };
      };

      sshd = {
        roles.server.tags = [ "all" ];
        roles.server.settings = {
          authorizedKeys = {
            "mac-mini" =
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILngYCsNBe3TMnnpOaxTnVoOCsJq1hq+ge5pYARiNWCC lubui.com@gmail.com";
          };
          certificate.searchDomains = [ "lan" ];
        };
        roles.client.tags = [ "all" ];
        roles.client.settings.certificate.searchDomains = [
          "lan"
          "wg"
        ];
      };

      # dyndns = {
      #   roles.default.machines.home-server = { };
      #   roles.default.settings = {
      #     settings = {
      #       "all-lubui-com" = {
      #         provider = "dnspod";
      #         domain = "lubui.com";
      #         secret_field_name = "token"; # dnspod token format "id,token"
      #         extraSettings = {
      #           host = "*,*.home"; # comma-separated list of sub-domains
      #           ip_version = "ipv4";
      #           ipv6_suffix = "";
      #         };
      #       };
      #     };
      #   };
      # };

      wifi = {
        module.name = "wifi";
        module.input = "clan-core";
        roles.default.machines = {
          nixos-desktop.settings.networks.home = { };
        };
      };

      # wireguard = {
      #   module.name = "wireguard";
      #   module.input = "clan-core";
      #   roles.controller = {
      #     machines.home-server = { };
      #     settings.endpoint = "home.lubui.com"; # 记得给home-server配置/etc/hosts: home.lubui.com局域网ip
      #     settings.domain = "wg";
      #   };
      #   roles.peer = {
      #     machines.orangepi5plus = { };
      #     settings.domain = "wg";
      #   };
      # };

    };
  };
}
