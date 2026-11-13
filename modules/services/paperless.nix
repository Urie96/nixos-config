{
  flake.nixosModules.paperless =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      cfg = config.services.paperless;
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

      # —— OCR 引擎：RapidOCR（PP-OCRv6）+ ONNX Runtime，替掉内置 tesseract ——
      #
      # 三条决定这里写法的事实：
      #
      #   1. paperless 调的是 ocrmypdf 的 **Python API**（`ocrmypdf.ocr(**args)`），
      #      而 ocrmypdf 建插件管理器时无条件执行
      #        load_setuptools_entrypoints('ocrmypdf')
      #      它扫的是 **sys.path 上的 dist-info**，所以插件只要出现在 PYTHONPATH
      #      里就会被自动注册；get_ocr_engine() 是 firstresult hook，pluggy 按
      #      「后注册先调用」，于是顶掉内置 tesseract 引擎。
      #      → paperless 侧不需要 --plugin，也不需要塞任何参数。
      #
      #   2. NixOS 模块的 `extraPythonPackages` 只做一件事：把这些包的
      #      site-packages 拼进服务的 PYTHONPATH（makePythonPath 会递归展开
      #      propagated 依赖，所以只列插件一个就够）。它不碰
      #      services.paperless.package，派生和 cache.nixos.org 完全一致。
      #
      #   3. 以前 NUR 里那套做法是「换 python scope + 把插件挂到 ocrmypdf 的
      #      dependencies 上」，那会让 tesseract / ocrmypdf / paperless-ngx
      #      三个包全退出官方缓存。现在那种改法已经不需要了。
      #
      # 必须用 ps（= cfg.package.python.pkgs，即 paperless 自己那套 scope）构建：
      # PYTHONPATH 排在 site-packages **之前**，用别的 scope 构建会把 paperless
      # 的 ocrmypdf/pillow 盖掉。
      #
      # 源码用 fetchFromGitHub 取固定 rev（不用 flake input：这里只要源码树，
      # 不要它的 flake 输出，也避免给 nixos-config 多养一个 follow）。
      # 升级：改 rev，再把 hash 换成 `nix flake prefetch --json <url>` 的 hash。
      rapidocrPlugin =
        ps:
        ps.buildPythonPackage {
          pname = "ocrmypdf-rapidocr";
          version = "0.3.0";
          pyproject = true;
          src = pkgs.fetchFromGitHub {
            owner = "Urie96";
            repo = "ocrmypdf-paddle-plugin";
            rev = "a0c11cd5065cba357d4e2305c79b3eae4c949380";
            hash = "sha256-5GEwFt27cZEdKH1jE7BvytuHmdaQUY/BkyqOg8sufS4=";
          };

          build-system = [ ps.setuptools ];
          dependencies = with ps; [
            ocrmypdf
            rapidocr
            onnxruntime
            pillow
          ];

          # 23 个用例全是不需要模型/网络的冒烟测试
          nativeCheckInputs = [ ps.pytest ];
          doCheck = true;
          pythonImportsCheck = [ "ocrmypdf_rapidocr" ];
        };
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
      # OIDC client_secret：明文给 paperless（下面塞进 EnvironmentFile，
      # 不进 nix store），pbkdf2 摘要给 authelia（它的 YAML 只收摘要）。
      #
      # AI 后端是本机 llama-server，不校验 Authorization，所以不需要 AI 的 key。
      clan.core.vars.generators.paperless-secrets = {
        files.client-secret = { };
        files.client-secret-hash.secret = false;
        files.env = { };

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
          cat > "$out/env" <<EOF
          PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"SCOPE":["openid","profile","email"],"APPS":[{"provider_id":"${oidcProviderId}","name":"Authelia","client_id":"${oidcClientId}","secret":"$(cat "$out/client-secret")","settings":{"server_url":"${autheliaUrl}","token_auth_method":"client_secret_basic","fetch_userinfo":true}}]}}
          EOF
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
        # 故意不设 package：默认就是 pkgs.paperless-ngx，和官方缓存一字不差
        # （实测 drvPath 与 stock 完全相同）。OCR 走 extraPythonPackages 注入。
        #
        # 想换回 NUR 那个「paperless_ai 依赖打空壳」的精简版，就写
        #   package = self.inputs.nur-packages.packages.${pkgs.stdenv.hostPlatform.system}.paperless;
        # 代价是 paperless-ngx 本地重建；省下的是 AI 那套 embedding 依赖
        # （torch 等约 3.4 GiB），现在这些全部来自缓存。
        extraPythonPackages = ps: [ (rapidocrPlugin ps) ];
        address = "127.0.0.1";
        port = 3117;
        domain = "paperless.lubui.com";
        # systemd 以 root 读出来经 LoadCredential 交给服务，secret 本体不进
        # nix store，也不需要 chown 给 paperless。
        passwordFile = config.clan.core.vars.generators.paperless.files.admin-password.path;
        # PAPERLESS_SOCIALACCOUNT_PROVIDERS（含 client_secret）走这里，不进 nix store。
        # 模块会把 environmentFile 同时挂到 4 个 systemd 单元和 paperless-manage。
        environmentFile = gen.files.env.path;
        consumptionDirIsPublic = true;

        # 本机 postgres 建库/建用户（services.postgresql 在 selfhost 里全局启用，
        # 这里只是追加 ensureDatabases / ensureUsers）。
        database.createLocally = true;

        # tesseract 现在只剩一个用途：ocrmypdf 启动时内置 tesseract 插件的
        # check_options 会跑 `tesseract --version`（pluggy 会把所有插件的
        # check_options 都跑，不看引擎选择）。
        #
        # null = 不裁语言包。这个值直接决定 services.paperless.package 的
        # drvPath：模块的 apply 钩子会
        #   pkg.override { tesseract5 = pkg.tesseract5.override { enableLanguages = null; }; }
        # 而 null 正是默认值，于是 apply 变成 no-op → tesseract/ocrmypdf/
        # paperless-ngx 全部命中 cache.nixos.org（代价是多带 ~1.1 GiB tessdata）。
        # 改成 [ "chi_sim" "eng" ] 能省掉这 1.1 GiB，但那三个包就得本地重建。
        tesseractLanguages = null;

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
          # 插件只认 chi_sim / eng（都走 PP-OCRv6 那个多语模型）。
          PAPERLESS_OCR_LANGUAGE = "chi_sim+eng";
          PAPERLESS_OCR_MODE = "auto";
          # 插件参数要调的话走 PAPERLESS_OCR_USER_ARGS：paperless 会把它 merge
          # 进 ocrmypdf.ocr(**args)，键名用 argparse 的 dest（例：
          #   PAPERLESS_OCR_USER_ARGS = { rapid_det_limit_type = "min";
          #                              rapid_det_limit_side_len = 736; };
          # 插件默认已是 small/max/960，一般不用动。

          # —— AI（本机 llama.cpp，走 openai-like 协议）——
          #
          # 后端是 modules/services/llama.nix 里那个 llama-server（router 模式，
          # 127.0.0.1:3119）。它不校验 Authorization，所以不需要 API key：
          # paperless 在没配 key 时会发占位符 "fake"。
          #
          # 只用「建议」这条路：PAPERLESS_AI_LLM_EMBEDDING_BACKEND 故意不设，
          # 所以不建向量索引、没有 RAG 问答。
          #
          # 依赖侧现在就靠官方 pkgs.paperless-ngx，AI embedding 那 3.4 GiB
          # （torch / sentence-transformers）全部来自缓存；以前是 NUR 用空壳包
          # 裁掉、代价是 paperless-ngx 本地重建。
          PAPERLESS_AI_ENABLED = true;
          PAPERLESS_AI_LLM_BACKEND = "openai-like";
          # 注意带 /v1：llama-index 的 OpenAILike 会把 api_base 后面拼 /chat/completions
          PAPERLESS_AI_LLM_ENDPOINT = "http://127.0.0.1:3119/v1";
          # router 模式下 model 就是 llama-models.ini 里的段名；那个 preset
          # 跟对话用的 Qwen3.5-9B 共用权重，但 temp 0、关 thinking。
          PAPERLESS_AI_LLM_MODEL = "paperless-classify";
          # 本机 Vulkan 推理比云端 API 慢（首请求还要加载权重），默认 120s 不够
          PAPERLESS_AI_LLM_REQUEST_TIMEOUT = 300;
          # 文档主要是中文，让标题/标签尽量输出中文
          PAPERLESS_AI_LLM_OUTPUT_LANGUAGE = "Chinese";
          # 127.0.0.1 默认就允许（PAPERLESS_AI_LLM_ALLOW_INTERNAL_ENDPOINTS 默认 true）
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
          # 关掉「Check all e-mail accounts」这条 celery beat 任务（默认每 10 分钟
          # 跑 paperless_mail.tasks.process_mail_accounts）。"disable" 是
          # paperless/settings/custom.py:parse_beat_schedule() 认的哨兵值，
          # 等于把该条目从 beat schedule 里删掉，不是改成某个奇怪的 cron。
          # 想恢复就删掉这行（或写成 "*/10 * * * *"）。
          PAPERLESS_EMAIL_TASK_CRON = "disable";
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
