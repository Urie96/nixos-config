{
  flake.nixosModules.translate-server =
    {
      config,
      ...
    }:
    {
      clan.core.vars.generators.translate-server = {
        prompts.token.type = "hidden";
        files.env = { };
        script = ''
          echo "API_TOKEN=$(cat $prompts/token)" > $out/env
        '';
      };

      virtualisation.oci-containers.containers.translate-server = {
        # podman.user = "urie";
        image = "xxnuo/mtranserver:3.0.1-beta2-zh";

        # image = "docker.io/xxnuo/mtranserver:3.0.1-beta2-zh";
        extraOptions = [
          "--network=host"
        ];
        environmentFiles = [
          config.clan.core.vars.generators.translate-server.files.env.path
        ];
      };

      services.nginx.virtualHosts."trans.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:8989";
          proxyWebsockets = true;
        };
      };
    };
}
