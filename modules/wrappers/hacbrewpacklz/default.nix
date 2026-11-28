{
  inputs,
  ...
}:
{
  flake.wrappers.hacbrewpacklz =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];

      options.keyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          prod.keys 的路径。非 null 时每次调用自动加上 `-k <路径>`。
        '';
      };

      config = {
        package = lib.mkDefault inputs.nur-packages.packages.${pkgs.stdenv.hostPlatform.system}.hacbrewpacklz;

        # 不能用 wlib 的 `flags`：flags 是前置参数，而 hacbrewpacklz 只把 args[0] 当子命令
        # （verify / details / look / compress…），见 Program.Run 的分派。前置换来的是
        #   `-k <keys> look <file>`
        # 于是子命令成了普通输入文件，程序报 "'look' not found"，并退回交互式 [C]ompress 提示。
        # 所以 `-k <keys>` 由脚本按位置插进去：有子命令就插在子命令后面，没有就放最前面。
        argv0type =
          _finalcmd:
          let
            exe = lib.escapeShellArg config.wrapperPaths.input;
            keys = lib.escapeShellArg config.keyFile;
          in
          if config.keyFile == null then
            ''exec -a "$0" ${exe} "$@"''
          else
            ''
              __hbpl_args=("$@")
              __hbpl_verb=""
              __hbpl_at=0
              for ((__hbpl_i = 0; __hbpl_i < ''${#__hbpl_args[@]}; __hbpl_i++)); do
                case "''${__hbpl_args[__hbpl_i]}" in
                  look|details|verify|compress|convert|extract|analyze|check|send|report|update|menu)
                    __hbpl_verb="''${__hbpl_args[__hbpl_i]}"
                    __hbpl_at=$__hbpl_i
                    break
                    ;;
                esac
              done
              case "$__hbpl_verb" in
                # 这几个不收选项：-k 会被当成要发送的文件、报告的正文或多余参数。
                send|report|update|menu)
                  exec -a "$0" ${exe} "''${__hbpl_args[@]}"
                  ;;
                # 没有子命令：按原来那样放最前面，比如构建 NSP 或 --help。
                "")
                  exec -a "$0" ${exe} -k ${keys} "''${__hbpl_args[@]}"
                  ;;
                *)
                  exec -a "$0" ${exe} "''${__hbpl_args[@]:0:__hbpl_at+1}" -k ${keys} "''${__hbpl_args[@]:__hbpl_at+1}"
                  ;;
              esac
            '';
      };
    };

  # 通用的 install 模块只负责声明 `wrappers.hacbrewpacklz.*`，
  # 真正装进 environment.systemPackages 要靠 enable 打开。
  # prod.keys 的声明也放在这里，机器配置只导入本模块，不用再写一遍。
  flake.nixosModules.hacbrewpacklz =
    { config, ... }:
    {
      wrappers.hacbrewpacklz.enable = true;

      # Switch 的 prod.keys 是从机器导出来的固定文件，不是随机生成的，所以 generator
      # 的 script 直接失败：值用
      #   clan vars set home-server switch-keys/prod.keys \
      #     < /home/urie/Downloads/switch/prod.keys
      # 写入（不加 --regenerate）。这样 `clan machines update` 会把它上传到
      # /var/lib/sops-nix，再由 sops-nix 解到 /run/secrets/vars/... 下。
      # 用 clan vars 而不是直接 sops 文件，是因为 clan 会按机器/用户 age key
      # 管理收件人，并自动上传。
      clan.core.vars.generators.switch-keys = {
        files."prod.keys" = {
          # hacbrewpacklz 由主用户交互运行，所以 secret 要归主用户所有。
          owner = config.my.mainUser.name;
          mode = "0400";
        };
        script = ''
          echo "switch-keys/prod.keys 要从 Switch 导出后用 clan vars set 写入，不能自动生成" >&2
          exit 1
        '';
      };

      # wrapper 拿这个路径当 `-k <keyset>`，也就是 /run/secrets/vars/... 下解密后的那份。
      wrappers.hacbrewpacklz.keyFile =
        config.clan.core.vars.generators.switch-keys.files."prod.keys".path;
    };
}
