{
  flake.nixosModules.aria2 =
    {
      config,
      pkgs,
      ...
    }:
    let
      domain = "aria.lubui.com";

      # 下载目录放外挂机械盘（btrfs label myHDD，subvol @data），别塞根分区，
      # 也别放 /var/lib（@varlib 会被 btrbk 每天快照 + 备份，下载文件没这个价值）。
      # /mnt/hdd 是 nofail 挂的，见下面 RequiresMountsFor。
      downloadDir = "/mnt/hdd/downloads/aria2";

      rpcPort = config.services.aria2.settings.rpc-listen-port;

      # 未完成任务在重启后接着下：save-session 写它，input-file 读它。
      sessionFile = "/var/lib/aria2/aria2.session";

      # AriaNg 是纯静态 SPA，root 指到包里的 dist 就行，不需要单独的反代。
      ariangRoot = "${pkgs.ariang}/share/ariang";

      secretFile = config.clan.core.vars.generators.aria2.files.rpc-secret.path;

      # nginx 的 https 端口由 modules/services/nginx.nix 定（8443）。AriaNg 的
      # RPC 地址是从浏览器那边发起的，所以这里必须写对外端口而不是 6800。
      webPort = config.services.nginx.defaultSSLListenPort;

      # AriaNg 的 hash 路由要求 secret 是 base64url（-/_ 字母表、无 padding）。
      # sops 模板只能做字面替换，不能在渲染阶段编码，所以 generator 里多产出一份
      # 派生值（rpc-secret-url）给下面的模板用。
      #
      # clan 的 generators-to-sops.nix 只把「vars store 里文件已存在」的 var 注册成
      # sops.secrets，所以从「加了新派生文件」到「跑过 vars generate」之间这里会
      # 取不到 placeholder。此时退化成跳到 AriaNg 首页（手填一次），生成完 vars
      # 重新部署就自动换成带 secret 的跳转，不会把求值弄挂。
      secretUrlKey = "vars/per-machine/home-server/aria2/rpc-secret-url";
      rpcSetRedirect =
        if builtins.hasAttr secretUrlKey config.sops.secrets then
          ''
            return 302 "https://${domain}:${toString webPort}/#!/settings/rpc/set/https/${domain}/${toString webPort}/jsonrpc/${config.sops.placeholder.${secretUrlKey}}";
          ''
        else
          ''
            return 302 "https://${domain}:${toString webPort}/";
          '';
    in
    {
      # RPC secret 不能写进 settings（会落到 world-readable 的 nix store，模块也
      # 有断言拦着），所以用 clan vars 生成随机值。service 模块自己用
      # LoadCredential 以 root 读出来交给 preStart 拼进 aria2.conf。
      #
      # 同时派生一份 base64url 版本给下面 nginx 的 `/rpc-set` 跳转用：AriaNg 的
      # hash 路由要求 secret 是 base64url（-/_ 字母表、无 padding），而 sops 模板
      # 只能做字面替换、不能在渲染阶段做编码，所以只能让 generator 先算好。
      clan.core.vars.generators.aria2 = {
        files.rpc-secret = { };
        files.rpc-secret-url = { };
        runtimeInputs = with pkgs; [
          coreutils
          openssl
        ];
        script = ''
          secret="$(openssl rand -hex 32 | tr -d '\n')"
          # 两个文件都不要尾换行：sops 占位符是纯字符串替换，换行会插进
          # nginx 的 Location 头里。
          printf %s "$secret" > "$out/rpc-secret"
          printf %s "$secret" | base64 -w0 | tr '+/' '-_' | tr -d '=' > "$out/rpc-secret-url"
        '';
      };

      services.aria2 = {
        enable = true;
        rpcSecretFile = secretFile;

        # 不对外开 BT/DHT/RPC 端口：Web 端只走下面的 nginx + authelia。
        # 开了 openPorts 只会把 6800 RPC 暴露到局域网，绕开鉴权。
        # BT 因此不可被外部连入（DHT/tracker 仍可主动连出），个人使用足够。
        openPorts = false;

        # 主用户加进 aria2 组（见下面 extraGroups），组内成员才能改下载好的文件。
        # 目录 0755：jellyfin / samba 之类的非组内用户也要能直接读；umask 0002
        # 下 aria2 写的文件是 0664、子目录 0775，同样全局可读。
        serviceUMask = "0002";
        downloadDirPermission = "0755";

        settings = {
          dir = downloadDir;

          # 断点续传 + 重启后继续未完成任务。模块的 preStart 会先 touch
          # save-session，所以 input-file 一定存在。
          continue = true;
          input-file = sessionFile;
          save-session = sessionFile;
          save-session-interval = 30;
          auto-save-interval = 60;

          # RPC 只监听回环，外部唯一入口是 nginx 的 /jsonrpc。
          rpc-listen-all = false;
          rpc-listen-port = 6800;
          rpc-allow-origin-all = false;

          # 家用单机下载的常用值：别把带宽/连接数打满，btrfs 上不做预分配。
          max-concurrent-downloads = 5;
          max-connection-per-server = 8;
          split = 8;
          min-split-size = "4M";
          file-allocation = "none";
          disk-cache = "64M";

          # 下完就不长期做种（外挂盘空间有限）。
          seed-ratio = 0.0;
        };
      };

      users.users.${config.my.mainUser.name}.extraGroups = [ "aria2" ];

      # 磁盘没插时别把下载写进根分区的 /mnt/hdd 挂载点。
      systemd.services.aria2.unitConfig.RequiresMountsFor = [ downloadDir ];

      # AriaNg 的 RPC 设置存在浏览器的 localStorage 里，第一次访问要手填
      # host/port/secret。这个 sops 模板渲染出一条 302，把 secret 拼进 AriaNg 的
      # hash 路由：
      #
      #   /#!/settings/rpc/set/https/<host>/<port>/jsonrpc/<base64url(secret)>
      #
      # AriaNg 打开这个路由后会自己把 RPC 设置写进 localStorage 再刷新，所以
      # Dashy 的入口直接指到 /rpc-set 就能连上，不用手输 token。
      #
      # 用 sops 模板而不是静态 return：nginx.conf 本身在 nix store 里，secret 不能
      # 出现在那里。模板由 sops 在系统 activation 里渲染到 /run/secrets/rendered
      # （本仓库没开 sops.useSystemdActivation，走 activation snippet），nginx 在
      # activation 之后才启动/重启，所以 include 的文件一定已经在了。
      # 渲染出来的文件 0400 nginx:nginx，只有 nginx worker 能读。
      sops.templates."aria2-rpc-redirect" = {
        content = rpcSetRedirect;
        owner = config.services.nginx.user;
        group = config.services.nginx.group;
        mode = "0400";
        # secret 轮换后只需 reload，nginx 会重读 include 的文件
        reloadUnits = [ "nginx.service" ];
      };

      services.nginx.virtualHosts.${domain} = {
        addSSL = true;
        useACMEHost = "lubui.com";

        # 8443 对公网开放，整站（含 /jsonrpc）先过 authelia 的 one_factor。
        extraConfig = config.my.authelia.nginxSsoConfig;

        locations = {
          "/authelia" = {
            extraConfig = config.my.authelia.nginxVerifyLocation;
          };

          "/" = {
            root = ariangRoot;
            tryFiles = "$uri $uri/ /index.html";
          };

          # Dashy 的 Aria2 入口指到这里，跳一次就带上 RPC secret。
          # 内容由上面 sops.templates."aria2-rpc-redirect" 渲染（不进 nix store）。
          "= /rpc-set" = {
            extraConfig = ''
              include ${config.sops.templates."aria2-rpc-redirect".path};
              # 跳转目标里带着 RPC secret，任何一层都别缓存这个 302
              add_header Cache-Control "no-store";
            '';
          };

          # AriaNg 的 RPC 走同源路径，页面是 https 也不会被 mixed content 拦。
          # proxyPass 不带 URI：aria2 的 RPC 端点本身就是 /jsonrpc。
          "/jsonrpc" = {
            proxyPass = "http://127.0.0.1:${toString rpcPort}";
            # AriaNg 也可以切到 ws:// 模式，这里顺手把 Upgrade 头带上。
            proxyWebsockets = true;
          };
        };
      };
    };
}
