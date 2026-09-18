{
  flake.nixosModules.rsshub =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      clan.core.vars.generators.github = {
        prompts.token.description = "Github token";
        prompts.token.persist = true;
        files.token.deploy = false;
      };

      clan.core.vars.generators.rsshub = {
        files.env = { };
        dependencies = [ "github" ];
        script = ''
          echo "GITHUB_ACCESS_TOKEN=$(cat $in/github/token)" >> $out/env
        '';
      };

      systemd.services.rsshub = {
        description = "rsshub Backend";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          CHROMIUM_EXECUTABLE_PATH = lib.getExe pkgs.chromium;
          PORT = "1200";
        };
        serviceConfig = {
          Restart = "always";
          DynamicUser = true;
          ExecStart = lib.getExe pkgs.rsshub;
          EnvironmentFile = config.clan.core.vars.generators.rsshub.files.env.path;
        };
      };
    };
}
