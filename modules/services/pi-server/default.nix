{
  flake.nixosModules.pi-server =
    {
      pkgs,
      config,
      inputs',
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;

      mcporter = pkgs.writeShellScriptBin "mcporter" ''
        exec ${pkgs.mcporter}/bin/mcporter --config ${./mcporter.json} "$@"
      '';
    in
    {
      clan.core.vars.generators.deepseek = {
        share = true;
        files.api-key = { };
        prompts.api-key.persist = true;
      };

      clan.core.vars.generators.pi-server = {
        files.env-file = { };
        dependencies = [ "deepseek" ];
        prompts.home-assistant-token = { };
        prompts.music-assistant-token = { };
        script = ''
          echo "DEEPSEEK_API_KEY=$(cat $in/deepseek/api-key)" >>"$out/env-file"
          echo "HOME_ASSISTANT_AUTH=\"Bearer $(cat $prompts/home-assistant-token)\"" >>"$out/env-file"
          echo "MUSIC_ASSISTANT_TOKEN=$(cat $prompts/music-assistant-token)" >>"$out/env-file"
        '';
      };

      systemd.services.pi-server = {
        path = [
          mcporter
        ]
        ++ (with pkgs; [
          bash
          bc
          cacert
          coreutils
          curl
          diffutils
          fd
          file
          findutils
          git
          gnugrep
          gnused
          gnutar
          gzip
          htmlq
          hurl
          jq
          less
          libarchive
          patch
          procps
          python3
          ripgrep
          tree
          unzip
          util-linux
          w3m
          wget
          which
          xz
          yq-go
          zip
          zstd
        ]);
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig = {
          Description = "pi-server service";
        };
        serviceConfig = {
          ExecStart = "${nur.pi-server}/bin/pi-server";
          WorkingDirectory = "/var/lib/pi-server";
          StateDirectory = "pi-server";
          Restart = "on-failure";
          RestartSec = "5s";
          Environment = [
            "PI_SERVER_PORT=3115"
            # "PI_ALLOW_BUILTIN_TOOLS=1"
          ];
          EnvironmentFile = config.clan.core.vars.generators.pi-server.files.env-file.path;
        };
      };
    };
}
