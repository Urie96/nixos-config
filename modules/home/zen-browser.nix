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
  flake.homeModules.zen-browser = { config, pkgs, ... }: {
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
        DontCheckDefaultBrowser = true;
        DisablePocket = true;
        # 走 policies.ExtensionSettings + 本地 file:// XPI，而不是
        # profiles.default.extensions.packages：后者会把 profile 的 extensions/
        # 目录换成指向 /nix/store 的只读软链，手动装扩展和扩展自更新都会失效。
        #
        # JSON 是 { <slug> = { id, url, hash }; }，slug 只当注释；ExtensionSettings
        # 的 key 必须是扩展真实的 ID（AMO 签发时写进 XPI 的 manifest.json，改了就装不上）。
        ExtensionSettings = lib.listToAttrs (
          map (
            e:
            lib.nameValuePair e.id {
              installation_mode = "normal_installed";
              updates_disabled = true;
              install_url = "file://${pkgs.fetchurl { inherit (e) url hash; }}";
            }
          ) (lib.attrValues (builtins.fromJSON (builtins.readFile ./zen-browser-extensions.json)))
        );
      };

      profiles.default = {
        # 只有一个 profile，id 固定 0（编号必须唯一且稳定）。
        id = 0;

        # 包由 flake/HM 提供、浏览器自更新已禁用，启动时不必再问是否设为默认。
        settings."browser.shell.checkDefaultBrowser" = false;
      };
    };
  };
}
