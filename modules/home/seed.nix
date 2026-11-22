{
  # home.seed：像 home.file，但只在目标不存在时把文件复制过去。
  flake.homeModules.common =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.home.seed;

      isAbsolutePath = lib.hasPrefix "/";

      # 和 home.file 一样的 shape：键是默认的目标路径，值可以直接给 path，
      # 也可以给一个带 source/target/... 的 attrset。
      # 刻意不做 home.file 的 enable/onChange/force 那一套：种子只在缺失时写入一次，
      # 没有"每次 activation 都同步"的需求，选项越少越不容易误用。
      seedType = lib.types.attrsOf (
        lib.types.coercedTo lib.types.path (source: { inherit source; }) (
          lib.types.submodule (
            { name, config, ... }:
            {
              options = {
                source = lib.mkOption {
                  type = lib.types.path;
                  description = ''
                    Source path of the file or directory to copy.
                    If {option}`text` is set, the source is a file containing that text.
                  '';
                };

                text = lib.mkOption {
                  type = lib.types.nullOr lib.types.lines;
                  default = null;
                  description = ''
                    Text content of the file. When non-null, {option}`source`
                    points to a file containing this text.
                  '';
                };

                target = lib.mkOption {
                  type = lib.types.nonEmptyStr;
                  default = name;
                  defaultText = lib.literalExpression "name";
                  description = ''
                    Target path. Either absolute or relative to the home directory.
                  '';
                };

                recursive = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Copy directories recursively (`cp -r`). Has no effect for files.
                  '';
                };

                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to seed this path.";
                };
              };

              config.source = lib.mkIf (config.text != null) (lib.mkDefault (pkgs.writeText name config.text));
            }
          )
        )
      );

      # 绝对路径原样用，相对路径按 home.file 的习惯相对 $HOME。
      targetOf =
        entry:
        if isAbsolutePath entry.target then
          entry.target
        else
          "${config.home.homeDirectory}/${entry.target}";

      # 复制而不是软链：目标必须是普通文件，程序要能就地改写。
      # 另外 /nix/store 里的文件是 0444，cp 会把只读位一起带过来，
      # 而种子的语义是"交给用户/程序接管的初始副本"，所以复制后补写权限。
      seedScript =
        name: entry:
        let
          target = targetOf entry;
          quotedTarget = lib.escapeShellArg target;
        in
        ''
          # home.seed."${name}"
          if [ ! -e ${quotedTarget} ] && [ ! -L ${quotedTarget} ]; then
            run mkdir -p ${lib.escapeShellArg (dirOf target)}
            run cp ${lib.optionalString entry.recursive "-r "}"${entry.source}" ${quotedTarget}
            run chmod -R u+w ${quotedTarget}
          fi
        '';

      enabledSeeds = lib.filterAttrs (_: entry: entry.enable) cfg;
    in
    {
      options.home.seed = lib.mkOption {
        type = seedType;
        default = { };
        example = lib.literalExpression ''
          {
            ".config/foo/conf.toml".source = ./conf.toml;
            "kodi-guisettings.xml" = {
              source = ./guisettings.xml;
              target = "/home/alice/.local/share/kodi/userdata/guisettings.xml";
            };
          }
        '';
        description = ''
          Attribute set of files to copy into the home directory **only if the
          target does not exist yet**.

          Unlike [](#opt-home.file), which creates a read-only symlink into the
          Nix store, the target is a regular file owned by the user. This makes
          it suitable for files that the program itself rewrites at runtime
          (Kodi settings, plugin state, ...): the rebuild never touches them,
          and the seed only provides the initial content.

          Consequence: changing the source in the configuration has no effect on
          an existing target. Delete the target file to re-seed it.
        '';
      };

      # writeBoundary 之后才有稳定的 $HOME 目录，和 home.file 的 linkGeneration 同层。
      # 这里不依赖 linkGeneration：种子是普通文件，和软链无关。
      config.home.activation.seedFiles = lib.mkIf (enabledSeeds != { }) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] (
          lib.concatStrings (lib.mapAttrsToList seedScript enabledSeeds)
        )
      );
    };
}
