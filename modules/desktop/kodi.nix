{
  flake.nixosModules.kodi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Kodi 只自带 resource.language.en_gb，其它语言包平时要在「插件 → 从库安装」里
      # 联网下载到 ~/.kodi/addons。这里改成声明式安装，省掉这一步。
      # 固件来自官方 addon 镜像的 omega 分支（对应 Kodi 21）：
      #   https://mirrors.kodi.tv/addons/omega/resource.language.zh_cn/
      # 升级 Kodi 大版本时要跟着换分支和版本号。
      zhCnLanguage =
        pkgs.runCommand "kodi-resource-language-zh_cn"
          {
            # toKodiAddon 会读 propagatedBuildInputs，runCommand 默认没这个属性
            propagatedBuildInputs = [ ];
          }
          ''
            mkdir -p $out/share/kodi/addons
            ${pkgs.unzip}/bin/unzip -q \
              ${
                pkgs.fetchurl {
                  url = "https://mirrors.kodi.tv/addons/omega/resource.language.zh_cn/resource.language.zh_cn-11.0.105.zip";
                  hash = "sha256-Ov0lZYH/tAxkOcj1XwDbdHRZ2XsOZk+XuEqraoGCGpo=";
                }
              } -d $out/share/kodi/addons
          '';

      # ── Kodi 的 settings XML 生成 ────────────────────────────────────────────
      # Kodi 的 userdata/guisettings.xml、addon_data/<addon>/settings.xml 都是同一个形状：
      #   <?xml ...?><settings version="2"><setting id="键">值</setting>...</settings>
      # nixpkgs 里没有现成的生成器：lib.generators 只有 JSON/INI/TOML/YAML，pkgs.formats
      # 没有 xml，home-manager 的 programs.kodi 自己是 builtins.toXML + xsltproc 绕一圈。
      # 所以这里就一个 attrset → XML 的小函数，值用 lib.escapeXML 转义（< & " 等）。
      # 键按字母序输出，保证结果是纯函数、同 attrset 永远同一份文件。
      kodiSettingsXml =
        name: attrs:
        let
          # XML 里布尔值要写 true/false：Nix 的 toString true 是 "1"、toString false 是 ""，
          # 直接塞进去 Kodi 会把 "1" 当非法值、把 "" 当空值。
          settingValue =
            value: if builtins.isBool value then (if value then "true" else "false") else toString value;
          entry = id: value: ''
            <setting id="${lib.escapeXML id}">${lib.escapeXML (settingValue value)}</setting>
          '';
        in
        pkgs.writeText name ''
          <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
          <settings version="2">
          ${lib.concatStrings (lib.mapAttrsToList entry attrs)}</settings>
        '';
    in
    {
      # Kodi 媒体中心，连 home-server 的 Jellyfin。
      #
      # 用 kodi-wayland：nixos-desktop 的会话是 Hyprland（Wayland），原生 Wayland 后端
      # 在缩放/全屏切换上比走 XWayland 更干净。若 Wayland 后端有问题（黑屏、掉帧等），
      # 把上面的 pkgs.kodi-wayland 换成 pkgs.kodi 即可退回 XWayland，其余不变。
      #
      # 注意：nixos-desktop 没接物理显示器时，Hyprland 的 headless 输出是由
      # modules/home/dotConfig/hypr/hyprland.lua 启动后才创建的，和 sunshine 一样存在竞态——
      # 开机后立刻开 Kodi 可能拿不到输出，等 Hyprland 起来再开即可。
      #
      # 包交给 home-manager 的 programs.kodi 管（自动进 home.packages，.desktop
      # 由 HM profile 的 XDG_DATA_DIRS 暴露给启动器），语言/字体/Jellyfin 设置靠下面的种子文件。
      home-manager.users = lib.mkIf (config.my.mainUser.name != null) {
        ${config.my.mainUser.name} =
          { config, ... }:
          let
            userdata = "${config.programs.kodi.datadir}/userdata";
          in
          {
            programs.kodi = {
              enable = true;
              package = pkgs.kodi-wayland.withPackages (p: [
                p.jellyfin
                p.youtube
                (p.toKodiAddon zhCnLanguage)
              ]);
            };

            home.seed = {
              "${userdata}/guisettings.xml".source = kodiSettingsXml "kodi-guisettings-seed.xml" {
                # 皮肤字体：Estuary 默认的 NotoSans-Regular.ttf 是拉丁子集，没有中文字形，
                # 不换就是满屏方块。Arial 这个 fontset 指向 Kodi 自带的 media/Fonts/arial.ttf
                # （DejaVu Sans，4.6 MB，含 CJK 字形）。
                "lookandfeel.font" = "Arial";
                # 界面语言：语言包由上面的 zhCnLanguage 装进 KODI_HOME/addons
                "locale.language" = "resource.language.zh_cn";
              };
              "${userdata}/addon_data/plugin.video.jellyfin/settings.xml".source =
                kodiSettingsXml "kodi-jellyfin-settings-seed.xml"
                  {
                    server = "http://192.168.2.1:8096";
                    username = "urie";
                    sslverify = true;
                    # 0 = 插件自己拼 addon 播放路径（不直接读媒体文件路径）
                    useDirectPaths = 0;
                    enableMusic = false;
                    groupedSets = false;
                  };
            };
          };
      };
    };
}
