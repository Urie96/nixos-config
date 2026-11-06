{
  flake.nixosModules.alertmanager =
    { config, ... }:
    {
      # vmalert -> alertmanager -> alertmanager-ntfy -> ntfy-sh(:3112)
      # vmalert 只会往 Alertmanager API 发告警，而 ntfy 的 publish API 是另一套
      # JSON，所以中间必须有一层转换；nixpkgs 的 alertmanager-ntfy 就是现成的。
      services.prometheus.alertmanager = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9093;

        # Alertmanager 默认还会在 0.0.0.0:9094 起 cluster gossip 端口。
        # 这里只有一个实例，不需要 HA，置空就不会监听 9094。
        extraFlags = [ "--cluster.listen-address=" ];

        configuration = {
          route = {
            receiver = "ntfy";
            group_by = [
              "alertname"
              "site"
              "host"
            ];
            group_wait = "10s";
            group_interval = "5m";
            repeat_interval = "12h";
          };
          receivers = [
            {
              name = "ntfy";
              webhook_configs = [
                {
                  url = "http://127.0.0.1:9095";
                  send_resolved = true;
                  max_alerts = 10;
                }
              ];
            }
          ];
        };
      };

      services.prometheus.alertmanager-ntfy = {
        enable = true;

        settings = {
          http.addr = "127.0.0.1:9095";
          ntfy.baseurl = "http://127.0.0.1:3112";
          ntfy.notification.topic = "cTpCazcWbXmkHLoG";

          ntfy.notification.priority = ''status == "firing" ? "high" : "default"'';

          # srvos 的默认规则只写 annotations.description（没有 summary），
          # 所以标题不能用默认模板的 summary，否则通知标题是空的。
          ntfy.notification.templates = {
            title = ''{{ if eq .Status "resolved" }}[恢复] {{ else }}[告警] {{ end }}{{ index .Labels "alertname" }}{{ with (or (index .Labels "site") (index .Labels "host") (index .Labels "instance")) }} ({{ . }}){{ end }}'';
            description = ''{{ with index .Annotations "summary" }}{{ . }}{{ "\n" }}{{ end }}{{ index .Annotations "description" }}'';
          };

          # 如果 ntfy 开了鉴权（auth-file 里有用户），这里需要 token。
          # 不要直接把 token 写进 nix store，用 extraConfigFiles 从 sops/clan vars 注入：
          #
          #   ntfy.auth.token = "tk_CHANGE_ME";
          #
          # 或者更安全：
          #
          #   extraConfigFiles = [
          #     config.sops.secrets.ntfy-alertmanager-token.path
          #   ];
          #
          # 对应 secret 文件内容：
          #
          #   ntfy:
          #     auth:
          #       token: tk_CHANGE_ME
        };
      };
    };
}
