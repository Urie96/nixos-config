{
  flake.nixosModules.llm-api-proxy =
    {
      inputs',
      lib,
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
    in
    {
      systemd.services.llm-api-proxy = {
        description = "LLM API Proxy";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          LISTEN_ADDR = "0.0.0.0:8121";
        };
        serviceConfig = {
          Restart = "always";
          DynamicUser = true;
          ExecStart = lib.getExe nur.llm-api-proxy;
        };
      };

      services.nginx.virtualHosts."llm.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        locations."/" = {
          proxyPass = "http://127.0.0.1:8121";
          proxyWebsockets = true;
        };
      };
    };
}
