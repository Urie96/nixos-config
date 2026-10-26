{
  self,
  lib,
  ...
}:
{
  # 上游 home-manager 模块在 macOS 上默认 signed：.app 原样安装，保留 Zen 的
  # 代码签名（1Password / iCloud 密码 / Touch ID / Gatekeeper 都依赖 Team ID）。
  # 代价是 wrapFirefox 往 bundle 内写东西的能力（extraPrefs 等）全部不可用，
  # policies 只能落到 `app.zen-browser.zen` 这个 defaults domain。Linux 上该选项
  # 无意义，policies 走 distribution/policies.json。
  flake.homeModules.zen-browser =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [ self.inputs.zen-browser.homeModules.beta ];

      # macOS 上 Zen 会自己另造 profile，两个门槛都要满足：
      # 1) 上游 #285：HM 把 profiles.ini 渲染成指向 /nix/store 的只读软链，浏览器写不进去
      #    （报 "An unexpected error has prevented your changes from being saved."）。
      # 2) Firefox 的 dedicated-profile 逻辑（nsToolkitProfileService.cpp）：没有
      #    `[Install<hash>] Default=…` 就算“本安装首次运行”，而首次运行只在 profile 目录里
      #    有 compatibility.ini（IsProfileForCurrentInstall 只要求文件存在、能解析、且没有
      #    [Compatibility] 里的 LastPlatformDir）时才会认领 `[ProfileN] Default=1`，否则
      #    CreateDefaultProfile() 新建一个 `<random>.Default (release)`。
      # 所以这里：给声明式 profile 预置 compatibility.ini，让 Firefox 首次启动就自己认领它
      # 并写入正确的 [Install<hash>]（不需要预先算 hash）；profiles.ini 则必须是可写实体文件。
      #
      # 但实体文件不能靠“先让 HM 建软链、激活末尾再把软链换成实体文件”来实现：下一次
      # switch 时 HM 在 checkLinkTargets 里看到目标不是软链也不是同内容，就按
      # backupFileExtension 把它挪到 profiles.ini.backup；再下一次因为 profiles.ini.backup
      # 已存在而直接失败（Existing file '…/profiles.ini.backup' would be clobbered）。
      # 所以改成：HM 只把渲染结果落在 profiles.ini.hm（软链，随时可覆盖，浏览器不读它），
      # 真正的 profiles.ini 由激活脚本落成实体文件：声明式部分每次 switch 重写（这样改
      # profile 配置能生效），浏览器自己写的 [Install<hash>] 段原样保留（键名随 .app 路径变化，
      # 属于本地状态，Nix 里算不出来）。
      home.file."${config.programs.zen-browser.configPath}/profiles.ini".target = lib.mkForce (
        "${config.programs.zen-browser.configPath}/profiles.ini.hm"
      );

      home.activation.zenProfilesIni = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        # 模板 profiles.ini.hm 由 linkGeneration 软链进来。
        after = [ "linkGeneration" ];
        before = [ ];
        data = ''
          zenDir=${lib.escapeShellArg config.programs.zen-browser.configPath}
          zenIni="$zenDir/profiles.ini"
          zenTemplate="$zenDir/profiles.ini.hm"

          run mkdir -p -- "$zenDir"

          # 保留浏览器写的 [Install<hash>] 段；旧配置下它可能已经被挪进 .backup。
          installSections="$(mktemp)"
          for candidate in "$zenIni" "$zenIni.backup"; do
            if [ -f "$candidate" ] && [ ! -L "$candidate" ]; then
              # 激活脚本的 PATH 里没有 awk，写成绝对路径。
              ${lib.getExe pkgs.gawk} '/^\[/ { keep = ($0 ~ /^\[Install/) } keep' "$candidate" >"$installSections"
              if [ -s "$installSections" ]; then
                break
              fi
            fi
          done

          zenIniNew="$(mktemp "$zenDir/.profiles.ini.XXXXXX")"
          {
            cat -- "$zenTemplate"
            if [ -s "$installSections" ]; then
              printf '\n'
              cat -- "$installSections"
            fi
          } >"$zenIniNew"
          run chmod 644 "$zenIniNew"
          run rm -f -- "$installSections"

          # 内容没变就不动，避免每次 switch 都换掉浏览器正在用的文件。
          if [ -f "$zenIni" ] && [ ! -L "$zenIni" ] && cmp -s "$zenIniNew" "$zenIni"; then
            run rm -f -- "$zenIniNew"
          else
            run mv -f -- "$zenIniNew" "$zenIni"
          fi

          # 浏览器每次启动都会重写 compatibility.ini，所以不能用 home.file 管（那会是只读软链）。
          zenCompat="$zenDir/Profiles/default/compatibility.ini"
          if [ -L "$zenCompat" ]; then
            run cp -- "$(readlink "$zenCompat")" "$zenCompat.hm-writable"
            run rm -- "$zenCompat"
            run mv -- "$zenCompat.hm-writable" "$zenCompat"
            run chmod 644 "$zenCompat"
          elif [ ! -e "$zenCompat" ]; then
            run mkdir -p -- "$zenDir/Profiles/default"
            printf '[Compatibility]\n' >"$zenCompat"
          fi
        '';
      };

      programs.zen-browser = {
        enable = true;

        darwin.packageMode = lib.mkDefault "signed";

        # HM 的 firefox 模块在 darwin 上默认 profileVersion = null（不写 [General] Version）。
        # 缺了它 Firefox 会把旧格式的 installs.ini 导入进来，覆盖我们选的 profile，
        # 所以显式写成和浏览器自己一样的 2（internal 选项，但就是 profiles.ini 的这个字段）。
        profileVersion = 2;

        # 上游模块已经把 DisableAppUpdate / DisableTelemetry 设成 mkDefault true，
        # 这里只补和渠道无关、且在 signed 模式下同样生效的策略。
        policies = {
          DisableAppUpdate = true; # 禁止浏览器自我更新
          DisablePocket = true; # 移除 Pocket 集成
          DisableFirefoxStudies = true; # 禁 Shield/Normandy 实验
          DisableTelemetry = true; # 关闭遥测
          DontCheckDefaultBrowser = true; # 启动时不再问「是否设为默认浏览器」
          DisableFeedbackCommands = true; # 移除「提交反馈 / 报告损坏站点」等菜单项
          NoDefaultBookmarks = true; # 不创建默认书签（Mozilla/Zen 的入门书签夹）
          OfferToSaveLogins = false; # 不再弹"保存此密码？"
        };

        profiles.default = {
          id = 0;

          # firefox-addons 的 flake 输出（packages / legacyPackages）是它自己
          # `import nixpkgs { inherit system; }` 出来的，config 为空，所以 unfree 和
          # insecure 检查都按默认值拒绝（immersive-translate 两条都踩）。这里把它的
          # overlay 装进本仓库的 pkgs，让检查走 nixpkgs.config 里声明的豁免。
          extensions.packages =
            with (pkgs.extend self.inputs.firefox-addons.overlays.default).firefox-addons; [
              immersive-translate
              bitwarden
              vimium
              stylus
              violentmonkey
            ];

          presets.betterfox.enable = true;

          settings = {
            "extensions.autoDisableScopes" = 0; # 允许 profile 目录里软链进来的 XPI 自动启用
            "browser.shell.checkDefaultBrowser" = false;
            "intl.locale.requested" = "zh-CN,en-US"; # 浏览器语言
            "intl.accept_languages" = "zh-CN,zh,en-US,en"; # 网站语言
            "intl.regional_prefs.use_os_locales" = true; # 根据您操作系统的“中文 (Hans, 中国大陆)”首选项设置日期、时间、数字格式和单位制。
            "browser.translations.neverTranslateLanguages" = "zh-Hans";
            "browser.translations.automaticallyPopup" = false; # 询问是否翻译整页
            "zen.tabs.show-newtab-vertical" = false; # 在标签页列表中显示新建按钮
            "services.sync.engine.spaces" = true; # Sync your sidebar across devices
            "zen.spaces-sync.normal-tabs" = true; # Include unpinned tabs
            "zen.mods.auto-update" = false; # 启动时自动更新已安装的模组
            "extensions.webextensions.ExtensionStorageIDB.enabled" = false; # 插件配置从indexdb回退到json文件
          };

          # 搜索引擎。HM 把这里渲染成 <profile>/search.json.mozlz4（mozlz4 = magic +
          # 4 字节长度 + LZ4 block），也就是浏览器自己维护引擎列表的那份缓存，取代它。
          # 代价：文件是指向 /nix/store 的只读软链，浏览器里改搜索设置（增删引擎、
          # 换默认）不会落盘，下次启动仍是这里声明的状态。
          #
          # 版本号不用管：HM 写 version = 12，Zen 1.23 的 SearchUtils.SETTINGS_VERSION
          # 是 14，读的时候会走 #migrateTo13/#migrateTo14（把 _isAppProvided 改名成
          # _isConfigEngine），不会被判 corrupt。
          search = {
            force = true; # Firefox 写入设置时会替换掉这个软链，force 让每次 switch 重新链接回来。
            default = "google";

            # Zen 自带的 config 引擎（google / 百度 / 维基 …）不需要在这里重写定义，
            # 它们仍由 search config 提供；列在 order 里只是固定下拉列表顺序。
            order = [
              "google"
              "github"
              "baidu"
              "wikipedia-zh-CN"
              "bing"
              "ddg"
              "perplexity"
            ];

            engines =
              let
                nixSnowflakeIcon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              in
              {
                "GitHub" = {
                  urls = [ { template = "https://github.com/search?q={searchTerms}&type=repositories"; } ];
                  definedAliases = [ "github" ];
                  icon = "https://github.githubassets.com/favicons/favicon.svg";
                };

                "Nix Options" = {
                  urls = [ { template = "https://search.nixos.org/options?channel=unstable&query={searchTerms}"; } ];
                  definedAliases = [ "nixos" ];
                  icon = nixSnowflakeIcon;
                };

                "Nix Packages" = {
                  urls = [ { template = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}"; } ];
                  definedAliases = [ "pkgs" ];
                  icon = nixSnowflakeIcon;
                };

                "ChatGPT" = {
                  urls = [ { template = "https://chat.openai.com?q={searchTerms}"; } ];
                  icon = "https://chatgpt.com/cdn/assets/favicon-eex17e9e.ico";
                  definedAliases = [
                    "@gpt"
                    "@chatgpt"
                  ];
                };

                bing.metaData.hidden = "true";
              };
          };
        };
      };
    };
}
