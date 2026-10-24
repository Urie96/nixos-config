{
  self,
  lib,
  ...
}:
let
  # 与 packages.<system>.<variant> 一一对应：beta（官方 beta 渠道）或
  # twilight（每日滚动构建）。声明式配置全部来自 inputs.zen-browser.homeModules.*。
  variant = "beta";
in
{
  # 上游 home-manager 模块在 macOS 上默认 signed：.app 原样安装，保留 Zen 的
  # 代码签名（1Password / iCloud 密码 / Touch ID / Gatekeeper 都依赖 Team ID）。
  # 代价是 wrapFirefox 往 bundle 内写东西的能力（extraPrefs 等）全部不可用，
  # policies 只能落到 `app.zen-browser.zen` 这个 defaults domain。Linux 上该选项
  # 无意义，policies 走 distribution/policies.json。
  flake.homeModules.zen-browser = { pkgs, ... }: {
    imports = [ self.inputs.zen-browser.homeModules.${variant} ];

    # macOS 上 Zen 会自己另造 profile，两个门槛都要满足：
    # 1) 上游 #285：HM 把 profiles.ini 渲染成指向 /nix/store 的只读软链，浏览器写不进去
    #    （报 "An unexpected error has prevented your changes from being saved."）。
    # 2) Firefox 的 dedicated-profile 逻辑（nsToolkitProfileService.cpp）：没有
    #    `[Install<hash>] Default=…` 就算“本安装首次运行”，而首次运行只在 profile 目录里
    #    有 compatibility.ini（IsProfileForCurrentInstall 只要求文件存在、能解析、且没有
    #    [Compatibility] 里的 LastPlatformDir）时才会认领 `[ProfileN] Default=1`，否则
    #    CreateDefaultProfile() 新建一个 `<random>.Default (release)`。
    # 所以这里：把 profiles.ini 变成可写实体文件；给声明式 profile 预置 compatibility.ini，
    # 让 Firefox 首次启动就自己认领它并写入正确的 [Install<hash>]（不需要预先算 hash）。
    home.activation.zenProfilesIniWritable = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      after = [ "writeBoundary" ];
      before = [ ];
      data = ''
        zenDir="$HOME/Library/Application Support/Zen"

        zenIni="$zenDir/profiles.ini"
        if [ -L "$zenIni" ]; then
          run cp -- "$(readlink "$zenIni")" "$zenIni.hm-writable"
          run rm -- "$zenIni"
          run mv -- "$zenIni.hm-writable" "$zenIni"
          run chmod 644 "$zenIni"
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
        # TODO: 暂时注释 —— AMO 从本机直连返回 HTTP 406，`pkgs.fetchurl` 拉不到 XPI，
        # 会把整个 switch 卡死。等 XPI 有办法拿到后（配代理，或把文件放进仓库）
        # 再把这块放开。
        #
        # 两种写法（任选其一）：
        #   a) 联网拉，自己维护 hash：
        #      xpi = pkgs.fetchurl {
        #        url = "https://addons.mozilla.org/firefox/downloads/file/5051983/immersive_translate-1.33.3.xpi";
        #        hash = "sha256-C94gRk+/6VOpHDBDJktu0GabUP/5+6SQJN1bZGsePVE="; # 1.33.3
        #      };
        #      install_url = "file://${xpi}";
        #   b) XPI 放进仓库，零网络零 hash：
        #      install_url = "file://${./assets/immersive_translate-1.33.3.xpi}";
        #
        # ExtensionSettings."{5efceaa7-f3a2-4e59-a54b-85319448e305}" = {
        #   # normal_installed：装上但允许在 about:addons 里禁用/卸载
        #   # （策略每次启动会重新断言）。想彻底锁死改成 "force_installed"。
        #   installation_mode = "normal_installed";
        #   install_url = "file://...";
        #   updates_disabled = true; # 不让 AMO 用新版顶掉 pin 住的版本
        # };
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
