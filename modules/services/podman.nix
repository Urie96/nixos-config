{
  flake.nixosModules.podman =
    { pkgs, ... }:
    {
      virtualisation = {
        containers = {
          enable = true;
          storage = {
            settings.storage = {
              driver = "btrfs";
              options.overlay.mountopt = "nodev,metacopy=on";
            }; # storage
            rootful.settings.storage = {
              runroot = "/run/containers/storage";
              graphroot = "/var/lib/containers/storage";
            }; # storage
          };
        };
        podman = {
          enable = true;
          dockerSocket.enable = true;
          dockerCompat = true; # Create a `docker` alias for podman
          defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
        };
        oci-containers.backend = "podman";
      };

      environment.systemPackages = with pkgs; [
        dive
        podman-tui
        passt
      ];
    };
}
