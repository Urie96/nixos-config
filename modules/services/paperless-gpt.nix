{
  flake.nixosModules.paperless-gpt =
    {
      config,
      lib,
      pkgs,
      inputs',
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;

      port = 3118;

      # paperless 只监听 127.0.0.1，paperless-gpt 走 API 直连，不绕 nginx。
      # 这要求 paperless 那边 ALLOWED_HOSTS 认得 127.0.0.1（见 modules/services/paperless.nix）。
      paperlessUrl = "http://127.0.0.1:${toString config.services.paperless.port}";

      # 每个 provider 用不同的环境变量名，只有一处映射，别在别处再写一遍。
      llmProvider = "openai";
      apiKeyEnv = {
        openai = "OPENAI_API_KEY";
        anthropic = "ANTHROPIC_API_KEY";
        mistral = "MISTRAL_API_KEY";
        googleai = "GOOGLEAI_API_KEY";
      };

      # 写进 EnvironmentFile 的一行一条，key 名随 provider 变。
      envLines = [
        ''printf 'PAPERLESS_API_TOKEN=%s\n' "$(cat "$in/paperless-gpt-secrets/paperless-api-token")"''
      ]
      ++ lib.optional (lib.hasAttr llmProvider apiKeyEnv) ''
        printf '${apiKeyEnv.${llmProvider}}=%s\n' "$(cat "$in/paperless-gpt-secrets/llm-api-key")"
      '';
    in
    {
      # Paperless 的 API token 和 LLM 的 key 都只能人肉提供：前者要在 Paperless 里
      # 给专用用户建（Profile → API Auth Token），后者是你自己的服务商凭据。
      #
      # 不用 type = "hidden"：clan 对留空的 hidden prompt 会自动生成随机值，
      # 生成出来的 token/key 是无效的，只会让服务起来后一堆 401。
      clan.core.vars.generators.paperless-gpt-secrets = {
        prompts.paperless-api-token = {
          type = "line";
          persist = true;
          description = ''
            Paperless-ngx 的 API token：在 Paperless 里建一个专用用户
            （需要能 view/change 文档、标签、通讯方、文档类型、自定义字段），
            然后 Profile → API Auth Token 复制那个 token。
          '';
        };

        prompts.llm-api-key = {
          type = "line";
          persist = true;
          description = ''
            LLM 服务商的 API key（provider = ${llmProvider}）。
            端点不需要鉴权时随便填一个占位值即可，比如 local。
            provider 换成 anthropic/mistral/googleai 时重新 `clan vars regenerate` 填新 key。
          '';
        };

        # 两个 prompt 已经以文件形式存在 vars 里，不需要再单独部署明文文件。
        files.paperless-api-token.deploy = false;
        files.llm-api-key.deploy = false;
      };

      # 拼成 systemd EnvironmentFile，避免密钥出现在 nix store 或 unit 里。
      clan.core.vars.generators.paperless-gpt-env = {
        dependencies = [ "paperless-gpt-secrets" ];
        files.env = { };
        runtimeInputs = [ pkgs.coreutils ];
        script = ''
          umask 077
          {
            ${lib.concatStringsSep "\n  " envLines}
          } > "$out/env"
        '';
      };

      users.users.paperless-gpt = {
        description = "paperless-gpt service user";
        isSystemUser = true;
        group = "paperless-gpt";
      };
      users.groups.paperless-gpt = { };

      systemd.services.paperless-gpt = {
        description = "paperless-gpt (LLM OCR and metadata for Paperless-ngx)";
        after = [
          "network-online.target"
          "paperless-web.service"
        ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          LISTEN_INTERFACE = "127.0.0.1:${toString port}";
          PAPERLESS_BASE_URL = paperlessUrl;

          LLM_PROVIDER = llmProvider;
          LLM_MODEL = "gpt-4o";
          # 文档主要是中文，让标题/标签尽量输出中文。
          LLM_LANGUAGE = "Chinese";

          # OCR 走视觉模型，provider / key 与上面元数据那条共用。
          OCR_PROVIDER = "llm";
          VISION_LLM_PROVIDER = llmProvider;
          VISION_LLM_MODEL = "gpt-4o";
          # page routing 只在 image 模式生效，且本次运行要产可搜索 PDF/hOCR 时自动关闭。
          OCR_PROCESS_MODE = "image";

          # 只解析第一页。上游默认 5 页；这里设 1 是明确的选择：
          # 大部分扫描件的关键信息在首页，正文写回是整字段替换，够用且最省 token。
          OCR_LIMIT_PAGES = "1";

          # 已有原生文字层的页直接用它的文本，不调模型（省 token 的大头）。
          # 判据见上游 page_routing.go：文字≥30 字符、无乱码、图片覆盖<20%、
          # 且有 20 个以上单词才算 "digital text layer"；
          # 「扫描图 + 隐形文字层」仍然会被送去重新 OCR，这正是我们要的。
          OCR_SKIP_DIGITAL_PAGES = "true";

          # 送模型前先压图：默认值（600 DPI / 4000 万像素 / 10 MiB）对视觉模型是浪费，
          # 它内部还会再缩到 ~2048 长边。这里按 A4 算约 220 DPI、4.7M 像素、JPEG ≤3 MiB。
          # 再往下压（<150 DPI）会开始伤中文小字的识别率。
          IMAGE_MAX_RENDER_DPI = "220";
          IMAGE_MAX_PIXEL_DIMENSION = "2600";
          IMAGE_MAX_TOTAL_PIXELS = "5000000";
          IMAGE_MAX_FILE_BYTES = "3145728";

          # 渲染页面/OG 预览图的缓存，默认落在 /tmp，这里给它一个持久目录。
          PAPERLESS_GPT_CACHE_DIR = "/var/cache/paperless-gpt";
        };

        serviceConfig = {
          Type = "simple";
          User = "paperless-gpt";
          Group = "paperless-gpt";
          Restart = "on-failure";
          RestartSec = "5s";

          # config/（UI 里保存的设置）、prompts/（含 workflows/）、db/（撤销历史和
          # OCR run 记录）都相对工作目录，必须是可写的持久目录，否则每次重启/更新都丢。
          WorkingDirectory = "/var/lib/paperless-gpt";
          StateDirectory = "paperless-gpt";
          CacheDirectory = "paperless-gpt";

          ExecStart = lib.getExe nur.paperless-gpt;
          EnvironmentFile = config.clan.core.vars.generators.paperless-gpt-env.files.env.path;

          # Hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          # 不要加 MemoryDenyWriteExecute：PDFium 走 wazero（WASM）执行，
          # 需要可执行的内存映射，加了会让第一次渲染直接崩。
        };
      };

      # paperless-gpt 自己没有认证（UI 和 /api/* 全裸），必须挂在 authelia 后面。
      # 这和 paperless 那个 vhost 的策略不同：paperless 自己有 OIDC，这里没有任何登录，
      # 门禁是唯一入口。
      services.nginx.virtualHosts."paperless-gpt.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        extraConfig = config.my.authelia.nginxForwardAuth;

        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${toString port}";
            proxyWebsockets = true;
            # 上传/下载大 PDF、整份 OCR 都可能超过默认 60s
            extraConfig = ''
              proxy_read_timeout 300s;
              proxy_send_timeout 300s;
              client_max_body_size 200m;
            '';
          };

          "/authelia" = {
            priority = 11;
            extraConfig = config.my.authelia.nginxVerifyLocation;
          };
        };
      };
    };
}
