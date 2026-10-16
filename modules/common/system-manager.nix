{
  # https://system-manager.net/main/reference/all-options/
  flake.sysModules.common =
    { pkgs, lib, ... }:
    {

      # NixOS 用它记录「装机时的版本」，很多模块据此挑默认值
      # （例如 services.postgresql 用它选 postgresql 主版本：>=26.11 → postgresql_18）。
      #
      # 这里故意写死而不是跟随 lib.trivial.release：一旦它随 nixpkgs 漂移，
      # postgresql 主版本就会变，和已存在的 dataDir 对不上。
      options.system.stateVersion = lib.mkOption {
        type = lib.types.str;
        default = "26.11";
        description = "NixOS 的 system.stateVersion（system-manager 没有这个 option）。";
      };

      nix.enable = true;

      services.userborn.enable = true;

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
      };

      environment.variables = {
        EDITOR = "nvim";
        MANPAGER = "nvim +Man!";
        HF_ENDPOINT = "https://hf-mirror.com";
      };

      # Nix 的 glibc 靠 LOCALE_ARCHIVE 找 locale 表，NixOS 是在 i18n 模块里全局设置的
      # （nixos/modules/config/i18n.nix → systemd.globalEnvironment）。
      # system-manager 不 import 那个模块，而主机（Debian 12）默认也没有
      # /usr/lib/locale/locale-archive，于是 Nix 程序 setlocale 全部拿到无效 locale。
      # 最先炸的是 postgres 的 initdb：
      #   initdb: error: invalid locale settings; check LANG and LC_* environment variables
      #
      # 想省 store 体积可以只打包用到的 locale（必须覆盖主机 LANG/LC_*）：
      #   pkgs.glibcLocales.override {
      #     allLocales = false;
      #     locales = [ "C.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
      #   }
      systemd.globalEnvironment.LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";

      # 交互 shell 里的 Nix 程序同理（写进 /etc/profile.d；Debian 自身的 glibc 不认
      # LOCALE_ARCHIVE，所以只影响外面这层 Nix 路径里的程序）
      environment.sessionVariables.LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";

      # Enable and configure services
      services = {
        # nginx.enable = true;
      };

      environment = {
        systemPackages = [
        ];
      };

      # 让 sudo 能找到 Nix 路径（/run/current-system/sw/bin）
      security.sudo = {
        enable = true;
        extraConfig = ''
          Defaults secure_path="/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        '';
      };
    };
}
