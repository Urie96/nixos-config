{
  flake.nixosModules.authelia =
    { config, pkgs, ... }:
    {
      # Vars generator for authelia secrets
      clan.core.vars.generators.authelia = {
        files.jwt-secret.owner = "authelia-main";
        files.storage-encryption-key.owner = "authelia-main";
        files.session-secret.owner = "authelia-main";
        files.users-database.owner = "authelia-main";

        runtimeInputs = with pkgs; [
          coreutils
          openssl
          gnused
        ];

        prompts.password.description = "Password for Authelia user urie";
        prompts.password.type = "hidden";

        script = ''
          gensecret() {
            openssl rand 64 | openssl base64 -A | tr '+/' '-_' | tr -d '='
          }
          gensecret > "$out/jwt-secret"
          gensecret > "$out/storage-encryption-key"
          gensecret > "$out/session-secret"

          password_hash="$(${pkgs.authelia}/bin/authelia crypto hash generate argon2 --password "$(cat "$prompts/password")" --no-confirm | sed -n 's/^Digest: //p')"
          cat > "$out/users-database" <<EOF
          users:
            urie:
              disabled: false
              displayname: urie
              password: "$password_hash"
              email: lubui.com@gmail.com
              groups:
                - admin
          EOF
        '';
      };

      services.authelia.instances.main = {
        enable = true;
        secrets = {
          jwtSecretFile = config.clan.core.vars.generators.authelia.files.jwt-secret.path;
          storageEncryptionKeyFile =
            config.clan.core.vars.generators.authelia.files.storage-encryption-key.path;
          sessionSecretFile = config.clan.core.vars.generators.authelia.files.session-secret.path;
        };

        settings = {
          theme = "dark";

          authentication_backend.file.path =
            config.clan.core.vars.generators.authelia.files.users-database.path;
          access_control.default_policy = "one_factor";
          session.cookies = [
            {
              domain = "lubui.com";
              authelia_url = "https://auth.lubui.com:8443";
              default_redirection_url = "https://home.lubui.com:8443";
            }
          ];
          storage.local.path = "/var/lib/authelia-main/db.sqlite3";
          notifier.filesystem.filename = "/var/lib/authelia-main/notifications.txt";
        };

      };

      services.nginx.virtualHosts."auth.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:9091";
          proxyWebsockets = true;
        };
      };

    };
}
