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
      cfg = config.services.paperless-gpt;
      nur = inputs'.nur-packages.packages;

      # paperless 只监听 127.0.0.1:28981，paperless-gpt 走 API 直连，不绕 nginx。
      # 这要求 paperless 那边 ALLOWED_HOSTS 认得 127.0.0.1（见 modules/services/paperless.nix）。
      paperlessPort = config.services.paperless.port;

      # 每个 provider 用不同的环境变量名，只有一处映射，别在别处再写一遍。
      apiKeyEnv = {
        openai = "OPENAI_API_KEY";
        anthropic = "ANTHROPIC_API_KEY";
        mistral = "MISTRAL_API_KEY";
        googleai = "GOOGLEAI_API_KEY";
      };

      # baseUrl 在两家 provider 上的环境变量名不同（openai 兼容端点 vs Ollama）。
      baseUrlEnv = {
        openai = "OPENAI_BASE_URL";
        ollama = "OLLAMA_HOST";
      };

      # 每行写进 EnvironmentFile 一条，key 名随 provider 变。
      envLines = [
        ''printf 'PAPERLESS_API_TOKEN=%s\n' "$(cat "$in/paperless-gpt-secrets/paperless-api-token")"''
      ]
      ++ lib.optional (lib.hasAttr cfg.llm.provider apiKeyEnv) ''
        printf '${apiKeyEnv.${cfg.llm.provider}}=%s\n' "$(cat "$in/paperless-gpt-secrets/llm-api-key")"
      '';
    in
    {
      options.services.paperless-gpt = {
        enable = lib.mkEnableOption "paperless-gpt（Paperless-ngx 的 LLM OCR / 元数据建议）" // {
          default = true;
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 28982;
          description = ''
            paperless-gpt 自己的网页/API 监听端口，只绑 127.0.0.1，对外由 nginx 反代。
          '';
        };

        paperlessBaseUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:${toString paperlessPort}";
          defaultText = lib.literalExpression ''"http://127.0.0.1:''${config.services.paperless.port}"'';
          description = ''
            Paperless-ngx 的 API 地址。默认在本机直连 paperless 的监听端口。
            换端口/换机器时改这里，别改模块里的常量。
          '';
        };

        llm = {
          provider = lib.mkOption {
            type = lib.types.enum [
              "openai"
              "ollama"
              "anthropic"
              "mistral"
              "googleai"
            ];
            default = "openai";
            description = ''
              元数据建议用的 provider。`openai` 表示「OpenAI 或任何 OpenAI 兼容端点」
              （配合 llm.baseUrl）；Ollama 用 `ollama`。
            '';
          };

          model = lib.mkOption {
            type = lib.types.str;
            default = "gpt-4o";
            description = "元数据建议用的模型名。";
          };

          baseUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "http://127.0.0.1:8121/v1";
            description = ''
              `openai` 对应的 OPENAI_BASE_URL（自建网关、OpenRouter 等），
              `ollama` 对应的 OLLAMA_HOST。`null` 表示用上游默认值
              （官方 OpenAI / 本机 Ollama）。
            '';
          };

          language = lib.mkOption {
            type = lib.types.str;
            default = "Chinese";
            description = ''
              文档主要语言，会被塞进 prompt（LLM_LANGUAGE）。默认中文，
              让标题/标签尽量输出中文。
            '';
          };
        };

        ocr = {
          provider = lib.mkOption {
            type = lib.types.enum [
              "llm"
              "azure"
              "google_docai"
              "mistral_ocr"
              "docling"
            ];
            default = "llm";
            description = ''
              OCR provider。`llm` 走视觉模型（复用 llm.* 的 provider 和 API key），
              其他几个需要各自的凭据，本模块只透传环境变量，不替你配置。
            '';
          };

          visionModel = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "minicpm-v";
            description = ''
              视觉模型名（VISION_LLM_MODEL）。`null` 表示沿用 llm.model；
              Ollama 上通常要单独指定（如 `qwen2.5vl:7b`、`minicpm-v`）。
            '';
          };

          processMode = lib.mkOption {
            type = lib.types.enum [
              "image"
              "pdf"
              "whole_pdf"
            ];
            default = "image";
            description = ''
              image / pdf / whole_pdf，与上游 OCR_PROCESS_MODE 一致。
              `image` 兼容所有 provider；`whole_pdf` 会忽略 limitPages。
            '';
          };

          limitPages = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 0;
            description = ''
              每次 OCR 最多处理多少页（OCR_LIMIT_PAGES），`0` = 不限。
              上游默认值是 5，这里刻意设成 0：截断的识别结果一旦被 Apply
              就会把文档正文改成残篇。
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.services.paperless.enable;
            message = "services.paperless-gpt 需要 services.paperless.enable = true（它只是 Paperless 的 API 客户端）";
          }
        ];

        services.paperless-gpt.llm = {
          provider = "openai";
          model = "deepseek-flash";
          baseUrl = "https://api.deepseek.com";
        };

        # Paperless 的 API token 和 LLM 的 key 都只能人肉提供：
        # 前者要在 Paperless 里给专用用户建（Profile → API Auth Token），
        # 后者是你自己的服务商凭据。所以两个都做成一次性 prompt。
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
              LLM 服务商的 API key（provider = ${cfg.llm.provider}）。
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
            LISTEN_INTERFACE = "127.0.0.1:${toString cfg.port}";
            PAPERLESS_BASE_URL = cfg.paperlessBaseUrl;

            LLM_PROVIDER = cfg.llm.provider;
            LLM_MODEL = cfg.llm.model;
            LLM_LANGUAGE = cfg.llm.language;

            VISION_LLM_PROVIDER = cfg.llm.provider;
            VISION_LLM_MODEL = if cfg.ocr.visionModel != null then cfg.ocr.visionModel else cfg.llm.model;
            OCR_PROVIDER = cfg.ocr.provider;
            OCR_PROCESS_MODE = cfg.ocr.processMode;
            OCR_LIMIT_PAGES = toString cfg.ocr.limitPages;

            # 渲染页面/OG 预览图的缓存，默认落在 /tmp，这里给它一个持久目录。
            PAPERLESS_GPT_CACHE_DIR = "/var/cache/paperless-gpt";
          }
          // lib.optionalAttrs (cfg.llm.baseUrl != null && lib.hasAttr cfg.llm.provider baseUrlEnv) {
            ${baseUrlEnv.${cfg.llm.provider}} = cfg.llm.baseUrl;
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
              proxyPass = "http://127.0.0.1:${toString cfg.port}";
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
    };
}
