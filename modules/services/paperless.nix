{
  flake.nixosModules.paperless =
    {
      config,
      lib,
      pkgs,
      inputs',
      ...
    }:
    let
      cfg = config.services.paperless;
      nur = inputs'.nur-packages.packages;
      # nginx 的 defaultSSLListenPort 是 8443，所有 vhost 的外部 URL 都要带端口
      url = "https://paperless.lubui.com:8443";
      autheliaUrl = config.my.authelia.url;

      # allauth 的 openid_connect provider 用 provider_id 拼回调地址：
      #   <PAPERLESS_URL>/accounts/oidc/<provider_id>/login/callback/
      # paperless 用 request.get_host() 拼，所以 nginx 必须把带端口的 Host 传过来
      # （见下面 "/" location 里的 proxy_set_header Host $host:$server_port）。
      oidcClientId = "paperless";
      oidcProviderId = "authelia";
      oidcCallback = "${url}/accounts/oidc/${oidcProviderId}/login/callback/";
      gen = config.clan.core.vars.generators.paperless-secrets;

      # —— OCR 引擎：PaddleOCR（PP-OCRv6 medium）+ ONNX Runtime ——
      #
      # 打包全在 NUR 里（nur-packages/pkgs/{paperless,ocrmypdf,ocrmypdf-paddle,
      # tesseract-slim}），这里只留三条会影响本模块写法的前置结论：
      #
      #   1. paperless 调的是 ocrmypdf 的 **Python API**（`ocrmypdf.ocr(**args)`），
      #      而 ocrmypdf 初始化时无条件执行
      #        pluggy_manager.load_setuptools_entrypoints('ocrmypdf')
      #      所以插件只要在同一个 python 环境里就会被自动注册；插件实现的
      #      get_ocr_engine() 是 firstresult hook，pluggy 按「后注册先调用」，
      #      于是顶掉内置 tesseract 引擎 —— paperless 侧不需要任何开关，
      #      也不用往 PAPERLESS_OCR_USER_ARGS 里塞 --plugin。
      #   2. 整个 python 环境是 3.13：paddlepaddle 只出到 cp313 的 wheel，
      #      而 nixpkgs 的 python3Packages 已经是 3.14。
      #   3. NUR 那个 derivation 是 pkgs.callPackage 出来的，所以保留了 `.override`：
      #      services.paperless.package 有个 apply 钩子，会对最终值再调一次
      #        pkg.override { tesseract5 = pkg.tesseract5.override { enableLanguages = ...; }; }
      #      而 `pkg.tesseract5` 来自 nixpkgs paperless-ngx 的 passthru —— 这也是
      #      下面 tesseractLanguages 还能生效的原因。
    in
    {
      clan.core.vars.generators.paperless = {
        # persist = true 的 prompt 会自动落成同名文件（clan 的 generator 会把
        # $prompts/<name> 拷到 $out/<name>），所以下面不需要再写 script。
        prompts.admin-password = {
          description = "paperless 本地应急管理员 admin 的登录密码（SSO 之外的兜底账号）";
          type = "hidden";
          persist = true;
        };
        files.admin-password = { };
      };

      # paperless 里那些「必须是环境变量、又不能进 nix store」的凭据：
      #   - OIDC client_secret：明文给 paperless（下面塞进 EnvironmentFile），
      #     pbkdf2 摘要给 authelia（它的 YAML 只收摘要）。
      #   - AI（DeepSeek）的 API key：paperless 只认 PAPERLESS_AI_LLM_API_KEY
      #     这个环境变量，没有 *_FILE 变体。
      clan.core.vars.generators.paperless-secrets = {
        files.client-secret = { };
        files.client-secret-hash.secret = false;
        files.env = { };
        # prompt 已经以文件形式存在 vars 里，不需要再单独部署明文 key
        files.llm-api-key.deploy = false;

        # 只能人肉提供：不用 type = "hidden"（留空的 hidden prompt 会被 clan
        # 自动填成随机值，生成出来的 key 无效，只会让每次建议都 401）。
        prompts.llm-api-key = {
          type = "line";
          persist = true;
          description = ''
            AI 建议用的 LLM API key：填 DeepSeek 的 key
            （platform.deepseek.com → API keys）。
          '';
        };

        runtimeInputs = with pkgs; [
          coreutils
          openssl
          gnused
        ];
        script = ''
          openssl rand -hex 32 | tr -d '\n' > "$out/client-secret"
          # 摘要末尾不要留换行：authelia 的 YAML 会把它写成 "...\n"，多一个字节
          # 就可能让 pbkdf2 比对失败（别的客户端脚本里留了换行，这里顺手去掉）。
          ${pkgs.authelia}/bin/authelia crypto hash generate pbkdf2 --variant sha512 \
            --password "$(cat "$out/client-secret")" |
            sed -n 's/^Digest: //p' | tr -d '\n' > "$out/client-secret-hash"

          # paperless 只接受 JSON 字符串，没有 *_FILE 变体，所以 client_secret 只能
          # 出现在环境变量里。这里写一行紧凑 JSON 当 systemd EnvironmentFile：
          # 值不含空格，systemd 不需要引号，JSON 里的双引号也照原样收下。
          {
            cat <<EOF
          PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"SCOPE":["openid","profile","email"],"APPS":[{"provider_id":"${oidcProviderId}","name":"Authelia","client_id":"${oidcClientId}","secret":"$(cat "$out/client-secret")","settings":{"server_url":"${autheliaUrl}","token_auth_method":"client_secret_basic","fetch_userinfo":true}}]}}
          EOF
            # prompt 文件在同一 generator 里是 $prompts/<name>（type = "line"，
            # 保证只有一行，不会把 EnvironmentFile 写坏）
            printf 'PAPERLESS_AI_LLM_API_KEY=%s\n' "$(cat "$prompts/llm-api-key")"
          } > "$out/env"
        '';
      };

      my.authelia.oidcClients = [
        {
          client_id = oidcClientId;
          client_name = "Paperless-ngx";
          client_secret = gen.files.client-secret-hash.value;
          public = false;
          # allauth 不指定 token_auth_method 时会看 discovery 里的
          # token_endpoint_auth_methods_supported 自己挑，而 authelia 两种都宣告，
          # 于是可能挑成 post 跟这里的 basic 对不上。两边都显式钉成 basic。
          token_endpoint_auth_method = "client_secret_basic";
          # allauth 默认不发 PKCE（OAUTH_PKCE_ENABLED=false）。注意 authelia 4.39 的
          # RequirePKCE = require_pkce || pkce_challenge_method != ""，所以这里连
          # pkce_challenge_method 都不能写，否则等于强制 PKCE，authorize 阶段直接报
          # "Clients must include a 'code_challenge'"（同 modules/services/gitea.nix）。
          require_pkce = false;
          redirect_uris = [ oidcCallback ];
          scopes = [
            "openid"
            "profile"
            "email"
          ];
          # 家里没开 TOTP；以后强制二次验证改成 "two_factor"
          authorization_policy = "one_factor";
          id_token_signed_response_alg = "RS256";
          access_token_signed_response_alg = "none";
          # allauth 拿 Bearer token GET userinfo 后直接当 JSON 解析，必须不签名
          userinfo_signed_response_alg = "none";
          # 不写 consent_mode：默认 pre-configured，请求的 scope 和这里配置的完全一致
          # 就不会弹授权确认页，authelia 已有会话时 OIDC 流程是静默完成的。
        }
      ];

      services.paperless = {
        enable = true;
        # PaddleOCR 那套打包在 NUR 里，见上面注释
        package = nur.paperless;
        address = "127.0.0.1";
        port = 3117;
        domain = "paperless.lubui.com";
        # systemd 以 root 读出来经 LoadCredential 交给服务，secret 本体不进
        # nix store，也不需要 chown 给 paperless。
        passwordFile = config.clan.core.vars.generators.paperless.files.admin-password.path;
        # PAPERLESS_SOCIALACCOUNT_PROVIDERS（含 client_secret）和
        # PAPERLESS_AI_LLM_API_KEY 走这里，不进 nix store。
        # 模块会把 environmentFile 同时挂到 4 个 systemd 单元和 paperless-manage。
        environmentFile = gen.files.env.path;
        consumptionDirIsPublic = true;

        # 本机 postgres 建库/建用户（services.postgresql 在 selfhost 里全局启用，
        # 这里只是追加 ensureDatabases / ensureUsers）。
        database.createLocally = true;

        # OCR 引擎现在是 PaddleOCR，tesseract 只剩「ocrmypdf 启动时会无条件
        # 跑一次 `tesseract --version`」这一个用途（内置 tesseract 插件的
        # check_options 不看 engine 选择，pluggy 会把所有 check_options 都跑）。
        # 所以留一个最小可用的 tesseract：语言包只编这里列的 + 模块固定追加的
        # eng/equ/osd（模块的 apply 钩子会
        #   unique(["equ" "osd" "eng"] ++ 这里的列表)
        # 传给 nur.paperless.tesseract5.override），tessdata 从 1.0 GiB 降到 ~25 MiB。
        # 彻底去掉得把 tesseract 换成只回 --version 的假二进制，不值得。
        tesseractLanguages = [
          "chi_sim"
          "eng"
        ];

        settings = {
          # 模块会用 domain 生成 https://paperless.lubui.com（没有端口），
          # 但实际入口是 :8443，不覆盖的话邮件、分享链接、OIDC 回调全是错的地址。
          PAPERLESS_URL = lib.mkForce url;
          # 放行 127.0.0.1：paperless-manage / 容器内的健康检查、以及本地 curl
          # 直连 127.0.0.1:<port> 时 Django 的 Host 校验需要它。
          PAPERLESS_ALLOWED_HOSTS = "paperless.lubui.com,127.0.0.1";
          PAPERLESS_CSRF_TRUSTED_ORIGINS = url;

          # 本地兜底管理员。别用 urie：SSO 首次登录会按 preferred_username 建一个
          # 同名用户，撞名之后 allauth 会给它加随机后缀，两个号很难分辨。
          PAPERLESS_ADMIN_USER = "admin";
          PAPERLESS_ADMIN_MAIL = "admin@localhost";

          # —— SSO（authelia OIDC）——
          # PAPERLESS_APPS 是 Django INSTALLED_APPS 的追加列表，逗号分隔。
          PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
          # 没有本地 paperless 账号时自动按 OIDC 信息建号
          PAPERLESS_SOCIAL_AUTO_SIGNUP = true;
          PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = true;
          # 让新 SSO 用户自动进这个组（组要先在网页里建好，权限配一次就行；
          # 组还不存在时 paperless 只是 filter 不到，不会报错）。
          PAPERLESS_SOCIAL_ACCOUNT_DEFAULT_GROUPS = "editors";
          # 进登录页直接跳 SSO，authelia 已有会话时整个流程是静默的（闪一下 → 已登录），
          # 不用再输一次密码；这也是这台不挂 forward-auth 之后唯一的登录入口。
          # 本地 admin 的密码表单仍在，但前端那个表单会被这个重定向跳过，
          # 要登录 admin 走 Django admin 自己的登录页：/admin/login/。
          PAPERLESS_REDIRECT_LOGIN_TO_SSO = true;
          # nginx 是唯一的入口，X-Forwarded-For 里的客户端 IP 可信；这也让
          # allauth 的限流按真实客户端算，而不是所有人共用 127.0.0.1 一个桶。
          PAPERLESS_TRUSTED_PROXIES = "127.0.0.1";

          # 中文扫描件是主要场景，顺手保留英文合同/发票。
          PAPERLESS_OCR_LANGUAGE = "chi_sim+eng";
          PAPERLESS_OCR_MODE = "auto";

          # —— AI（DeepSeek，走 openai-like 协议）——
          #
          # 只用「建议」这条路：PAPERLESS_AI_LLM_EMBEDDING_BACKEND 故意不设，
          # 所以不建向量索引、没有 RAG 问答；但 get_taxonomy_context() 在没有
          # embedding 时会退化成 Tantivy 的 more_like_this 来取候选标签/
          # 通讯方/文档类型，建议质量仍然靠已有分类法兜底。
          #
          # 依赖侧只保留 llama-index-llms-openai-like（见 nur-packages
          # pkgs/paperless/default.nix 的 stubbedAiDeps），torch / HF embedding
          # 那 3.4 GiB 继续是空壳。
          PAPERLESS_AI_ENABLED = true;
          PAPERLESS_AI_LLM_BACKEND = "openai-like";
          PAPERLESS_AI_LLM_ENDPOINT = "https://api.deepseek.com";
          PAPERLESS_AI_LLM_MODEL = "deepseek-flash";
          # 文档主要是中文，让标题/标签尽量输出中文
          PAPERLESS_AI_LLM_OUTPUT_LANGUAGE = "Chinese";
          # 不开 thinking：deepseek-flash 默认开思考，而 thinking 模式会拒绝
          # paperless 发的强制 tool_choice。3.1.x 没有
          # PAPERLESS_AI_LLM_EXTRA_PARAMS 这个口子（3.3.0 才加），所以这一项是
          # 在 nur-packages/pkgs/paperless/default.nix 里用 postPatch 把
          # additional_kwargs 直接塞给 OpenAILike 的。
          PAPERLESS_TASK_WORKERS = 2;
          PAPERLESS_THREADS_PER_WORKER = 1;
          PAPERLESS_CONSUMER_RECURSIVE = true;
          PAPERLESS_CONSUMER_IGNORE_PATTERN = [
            ".DS_STORE/*"
            "desktop.ini"
            "Thumbs.db"
          ];
          PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
          PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = true;
        };
      };

      services.nginx.virtualHosts."paperless.lubui.com" = {
        addSSL = true;
        useACMEHost = "lubui.com";

        # 故意不挂 authelia 的 forward-auth（和 modules/services/lldap.nix 一个道理）。
        #
        # paperless 自己有完整认证（OIDC + 本地 admin），再套一层门禁的后果是：
        #   - 两次登录体感：先过 authelia，进了 paperless 再被 JS 跳一次 SSO；
        #   - `/admin/login/` 也被挡在门禁后面，本地 admin 页面根本进不去（门禁是
        #     server 级的，跟路径无关）。
        # 现在“谁能进来”只由 paperless 自己决定，authelia 只在你登 SSO 时才参与。
        #
        # 代价：paperless 自己的登录页（含本地 admin 的密码表单）和 Django admin
        # 直接暴露在公网 8443 上，成为可爆破的密码入口。只有一两个真人用户，
        # 而且 authelia 挂掉时还能用 admin 进来救急，接受这个代价。
        locations = {
          # 静态文件由 nginx 直接给（Django 在 DEBUG=false 下不服务它们），
          # 路径和 nixpkgs 模块自己 configureNginx 时的写法一致。
          "/static/" = {
            root = cfg.package;
            extraConfig = ''
              rewrite ^/(.*)$ /lib/paperless-ngx/$1 break;
            '';
          };

          "/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            # /ws/status 是前端轮询任务进度用的 websocket
            proxyWebsockets = true;

            # allauth 用 request.get_host() 拼 OIDC 回调地址，而 recommendedProxySettings
            # 发的 Host 是 $host（丢掉端口）→ 回调会变成 .../callback 而 authelia 那边
            # 配的是 :8443，字符串比对直接失败。这里手写整套头。
            #
            # 不用 $http_host：那是客户端发来的 Host 原文，带不带端口全看客户端
            # （curl/脚本可能只发 Host: paperless.lubui.com），丢了端口就回到上面
            # 那个错回调。$host 是 nginx 规范化后的主机名（小写、无端口），
            # $server_port 是实际监听端口（defaultSSLListenPort=8443），结果确定。
            recommendedProxySettings = false;
            extraConfig = ''
              proxy_set_header Host $host:$server_port;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-Host $host:$server_port;
              proxy_set_header X-Forwarded-Server $host;
              proxy_redirect off;

              # 上传大 PDF / 整批扫描件时别被默认超时掐掉
              proxy_read_timeout 300s;
              proxy_send_timeout 300s;
            '';
          };
        };
      };
    };
}
