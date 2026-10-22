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
        nssmdns4 = true;

        # nixpkgs 26.11 起 avahi-daemon.conf 由 settings 直接生成，
        # 原来的 services.avahi.{hostName,reflector,publish.*} 已改名到
        # services.avahi.settings.*（publish.enable / publish.userServices
        # 是废弃兼容项，这里直接写成等价的新选项）。
        settings = {
          server.host-name = "homeassistant"; # xiaomi home需要

          reflector.enable-reflector = true;

          publish = {
            disable-publishing = false;
            disable-user-service-publishing = false;
            publish-addresses = true;
            publish-domain = true;
            publish-hinfo = true;
            publish-workstation = true;
          };
        };
      };
    };
  };
}
