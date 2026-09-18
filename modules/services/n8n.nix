{
  flake.nixosModules.n8n =
    {
      config,
      pkgs,
      ...
    }:
    {
      clan.core.vars.generators.n8n-task-runner = {
        files.auth-token.secret = true;
        script = ''
          printf '%s' "$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64)" > "$out/auth-token"
        '';
      };

      services.n8n = {
        taskRunners.enable = true;
        enable = true;
        environment = {
          N8N_RUNNERS_AUTH_TOKEN_FILE =
            config.clan.core.vars.generators.n8n-task-runner.files.auth-token.path;
          WEBHOOK_URL = "https://n8n.thalheim.io/";

          # Database configuration
          DB_TYPE = "postgresdb";
          DB_POSTGRESDB_HOST = "/run/postgresql";
          DB_POSTGRESDB_DATABASE = "n8n";
          DB_POSTGRESDB_USER = "n8n";

          # Executions pruning
          EXECUTIONS_DATA_PRUNE = "true";
          EXECUTIONS_DATA_MAX_AGE = "336"; # 2 weeks
        };
      };

      services.postgresql = {
        enable = true;
        ensureDatabases = [ "n8n" ];
        ensureUsers = [
          {
            name = "n8n";
            ensureDBOwnership = true;
          }
        ];
      };

      services.nginx.virtualHosts."n8n.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.n8n.environment.N8N_PORT}";
          proxyWebsockets = true;
        };
      };
    };
}
