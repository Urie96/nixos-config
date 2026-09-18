{
  flake.nixosModules.podman =
    { pkgs, ... }:
    {
      virtualisation = {
        containers = {
          enable = true;
          storage.settings = {
            storage = {
              driver = "btrfs";
              runroot = "/run/containers/storage";
              graphroot = "/var/lib/containers/storage";
              options.overlay.mountopt = "nodev,metacopy=on";
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
