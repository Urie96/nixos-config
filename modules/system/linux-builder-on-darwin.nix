{ self, ... }:
let
  inherit (self.inputs) nixpkgs;
in
{
  flake.darwinModules.linux-builder-on-darwin =
    { pkgs, lib, ... }:
    let
      system = "aarch64-darwin";
      linuxSystem = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
    in
    {
      nix.distributedBuilds = true;
      nix.buildMachines = [
        {
          hostName = "localhost";
          sshUser = "builder";
          sshKey = "/etc/nix/builder_ed25519";
          system = linuxSystem;
          maxJobs = 4;
          supportedFeatures = [
            "kvm"
            "benchmark"
            "big-parallel"
          ];
        }
      ];

      launchd.daemons.darwin-builder =
        let
          darwin-builder = nixpkgs.lib.nixosSystem {
            system = linuxSystem;
            modules = [
              "${nixpkgs}/nixos/modules/profiles/nix-builder-vm.nix"
              {
                virtualisation = {
                  host.pkgs = pkgs;
                  darwin-builder.workingDirectory = "/var/lib/darwin-builder";
                  darwin-builder.hostPort = 22;
                };
              }
            ];
          };
        in
        {
          command = lib.getExe darwin-builder.config.system.build.macos-builder-installer;
          serviceConfig = {
            KeepAlive = true;
            RunAtLoad = true;
            StandardOutPath = "/var/log/darwin-builder.log";
            StandardErrorPath = "/var/log/darwin-builder.log";
          };
        };
    };
}
