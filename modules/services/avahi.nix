{
  flake.nixosModules.avahi = {
    services = {
      # resolved = {
      #   enable = true;
      #   extraConfig = ''
      #     MulticastDNS=yes
      #   '';
      # };
      # nscd.enableNsncd = false;
      avahi = {
        enable = true;
        hostName = "homeassistant"; # xiaomi home需要
        nssmdns4 = true;
        reflector = true;
        publish = {
          enable = true;
          addresses = true;
          domain = true;
          hinfo = true;
          userServices = true;
          workstation = true;
        };
      };
    };
  };
}
