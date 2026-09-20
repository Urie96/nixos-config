{
  flake.wrappers.mbsync =
    # mbsync（isync）wrapper 模块（通用部分），本机账号见 ./default.nix。
    #
    # isync 的配置是一串「段」，段头行开始、空行结束，行首 `#` 是注释：
    #
    #   IMAPAccount qq
    #   Host imap.qq.com
    #   PassCmd "rbw get 'qq imap'"
    #
    #   IMAPStore qq-remote
    #   Account qq
    #
    # 和常见的 INI 不同，它是**单趟**解析的：`Account` 必须先有对应的
    # `IMAPAccount`，`Far :store:` 必须先有对应的 Store，否则直接报
    # "unknown store 'x'" / "unknown IMAP account 'x'"。所以：
    #   - `accounts.<name>` 按 IMAPAccount → IMAPStore → MaildirStore → Channel
    #     的合法顺序生成四个段；
    #   - `sections` 用来写额外的段，生成在 `accounts` 的段之后；段之间要互相
    #     引用时用 `before` / `after` 排序（DAG）。引用 `accounts` 里的段不用排，
    #     生成顺序已经保证在前。
    #
    # 参数含空格时必须用双引号括起来，引号里的 `\` 和 `"` 要转义（mbsync(1)
    # 的 CONFIGURATION 段），这里统一处理，写配置时不用自己加引号。
    #
    # mbsync 没有「配置文件」环境变量，只有 `-c`；不指定时它依次找
    # $XDG_CONFIG_HOME/isyncrc 和 ~/.mbsyncrc。本 wrapper 一律用 `-c` 指到
    # wrapper 输出里的那份配置。
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    let
      # 段里的一个参数值：单个值，或者一个列表（列表 = 一个关键字带多个参数，
      # 比如 `Patterns * !Virtual*`、`Channels qq ustc`）。
      argValue = lib.types.oneOf [
        wlib.types.stringable
        (lib.types.listOf wlib.types.stringable)
      ];

      argType = lib.types.nullOr argValue;

      sectionType = lib.types.attrsOf argType;

      # isync 只认 IMAPS / STARTTLS / None。
      tlsTypes = {
        imaps = "IMAPS";
        starttls = "STARTTLS";
        none = "None";
      };

      # 含空格等字符的参数必须加引号；引号内的 `\` 和 `"` 要转义。
      # 反过来能不加就不加，生成的配置尽量接近手写的样子。
      bareArg = "[A-Za-z0-9_@%+=:,./*!~^-]+";

      quoteArg =
        value:
        let
          str = toString value;
        in
        if builtins.match bareArg str != null then
          str
        else
          "\"${lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] str}\"";

      renderArg =
        value:
        if builtins.isList value then lib.concatMapStringsSep " " renderArg value else quoteArg value;

      # null 表示「不写这一行」，交给 mbsync 用它自己的默认值。
      renderSection =
        header: section:
        lib.concatLines (
          [ header ]
          ++ lib.mapAttrsToList (key: value: "${key} ${renderArg value}") (
            lib.filterAttrs (_: value: value != null) section
          )
        );

      # 段之间必须空一行，否则后一个段头会被当成前一个段的参数。
      # renderSection 末尾已经有一个换行（concatLines），这里再补一个空的。
      renderBlock = header: section: renderSection header section + "\n";

      # accounts.<name> → 四个段。属性名既当账号名也当 channel 名，
      # 所以 `mbsync <name>` 只同步这一个账号。
      accountSections =
        name: account:
        let
          remote = "${name}-remote";
          local = "${name}-local";
        in
        [
          {
            header = "IMAPAccount ${name}";
            section = {
              Host = account.host;
              User = account.user;
              Port = account.port;
              Pass = account.password;
              PassCmd = account.passCmd;
              TLSType = tlsTypes.${account.tls};
              CertificateFile = account.certificateFile;
            }
            // account.extraAccountOptions;
          }
          {
            header = "IMAPStore ${remote}";
            section = {
              Account = name;
            }
            // account.extraImapStoreOptions;
          }
          {
            header = "MaildirStore ${local}";
            section = {
              Inbox = if account.maildir != null then account.maildir else "${config.maildirRoot}/${name}/";
              SubFolders = account.subFolders;
            }
            // account.extraMaildirStoreOptions;
          }
          {
            header = "Channel ${name}";
            section = {
              Far = ":${remote}:";
              Near = ":${local}:";
              Create = account.create;
              Expunge = account.expunge;
              SyncState = account.syncState;
              Patterns = account.patterns;
            }
            // account.extraChannelOptions;
          }
        ];

      renderAccount =
        name: account:
        if account.password != null && account.passCmd != null then
          throw "mbsync wrapper: accounts.${name} 同时设置了 `password` 和 `passCmd`，isync 只接受其中一个"
        else
          lib.concatStrings (map (s: renderBlock s.header s.section) (accountSections name account));

      renderedAccounts = lib.concatStrings (lib.mapAttrsToList renderAccount config.accounts);

      # 自写的段：`name` 是段头行（如 "Group all"），值是段里的关键字。
      renderedSections = lib.concatStrings (
        map (entry: renderBlock entry.name entry.data) (
          wlib.dag.unwrapSort "mbsync.sections" config.sections
        )
      );
    in
    {
      imports = [ wlib.modules.default ];

      options = {
        maildirRoot = lib.mkOption {
          type = wlib.types.nonEmptyLine;
          default = "~/mail";
          example = "~/Mail";
          description = ''
            本地 Maildir 的根目录。`accounts.<name>` 默认用 `<maildirRoot>/<name>/`
            当 `Inbox`。mbsync 在所有本地路径上支持 `~` 展开；相对路径的参照点是
            配置文件所在目录（store 里），所以别写相对路径。
          '';
        };

        accounts = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                host = lib.mkOption {
                  type = lib.types.nullOr wlib.types.nonEmptyLine;
                  default = null;
                  example = "imap.gmail.com";
                  description = "IMAP 服务器（`Host`）。";
                };

                user = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "urie@mail.ustc.edu.cn";
                  description = "登录名（`User`）。";
                };

                passCmd = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "rbw get 'qq imap'";
                  description = ''
                    取密码的 shell 命令（`PassCmd`），比如 `rbw get 'qq imap'`。
                    含空格也没关系，wrapper 会加引号。和 `password` 互斥。
                  '';
                };

                password = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    明文密码（`Pass`）。会写进 store，除非是 sops 之类的运行时占位符，
                    否则建议用 `passCmd`。和 `passCmd` 互斥。
                  '';
                };

                tls = lib.mkOption {
                  type = lib.types.enum (builtins.attrNames tlsTypes);
                  default = "imaps";
                  description = "连接加密方式（`TLSType`）：imaps(993) / starttls(143) / none。";
                };

                port = lib.mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = "端口（`Port`）。默认由 `tls` 决定：IMAPS 993、其它 143。";
                };

                certificateFile = lib.mkOption {
                  type = lib.types.nullOr wlib.types.stringable;
                  default = null;
                  example = "/etc/ssl/certs/ca-certificates.crt";
                  description = "校验服务器证书用的 CA bundle（`CertificateFile`）。";
                };

                maildir = lib.mkOption {
                  type = lib.types.nullOr wlib.types.stringable;
                  default = null;
                  defaultText = lib.literalExpression ''"<maildirRoot>/<账号名>/"'';
                  example = "~/mail/qq/";
                  description = ''
                    本地 Maildir 的 `Inbox` 路径。结尾的 `/` 是必须的
                    （`Inbox` 指的是目录本身，不是它的父目录）。
                  '';
                };

                subFolders = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.enum [
                      "Maildir++"
                      "Verbatim"
                      "Legacy"
                    ]
                  );
                  default = "Maildir++";
                  description = ''
                    子文件夹的落盘风格（`SubFolders`）。Dovecot/Courier 用 Maildir++
                    （收件箱下的 `.文件夹`），纯 Maildir 树用 Verbatim；
                    `null` = 不写这一行，碰到子文件夹时 mbsync 会报错。
                  '';
                };

                patterns = lib.mkOption {
                  type = lib.types.nullOr (lib.types.listOf wlib.types.nonEmptyLine);
                  default = [
                    "*"
                    "!Virtual*"
                  ];
                  description = ''
                    `Channel` 的 `Patterns`：要同步的邮箱（IMAP4 通配符），
                    前面加 `!` 是排除。`null` = 不写这一行，只同步 `Far`/`Near`
                    指名的那一个邮箱。
                  '';
                };

                create = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.enum [
                      "None"
                      "Far"
                      "Near"
                      "Both"
                    ]
                  );
                  default = "Both";
                  description = "自动创建缺失的邮箱（`Create`）。";
                };

                expunge = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.enum [
                      "None"
                      "Far"
                      "Near"
                      "Both"
                    ]
                  );
                  default = "Both";
                  description = "在一侧删除后真正 expunge 哪一侧（`Expunge`）。";
                };

                syncState = lib.mkOption {
                  type = lib.types.nullOr wlib.types.nonEmptyLine;
                  default = "*";
                  description = ''
                    同步状态文件的位置（`SyncState`）。`*` = 放在 near 侧邮箱里
                    （每个邮箱一个 `.mbsyncstate`）。
                  '';
                };

                extraAccountOptions = lib.mkOption {
                  type = sectionType;
                  default = { };
                  example = lib.literalExpression ''{ AuthMechs = [ "LOGIN" ]; PipelineDepth = "5"; }'';
                  description = ''
                    追加到 `IMAPAccount` 段的其他关键字（键名和 isync 一致，大小写不敏感），
                    例如 `AuthMechs` / `Tunnel` / `PipelineDepth` / `UseKeychain`。
                    值会做引号转义，列表 = 一个关键字带多个参数；`null` = 不写这一行。
                  '';
                };

                extraImapStoreOptions = lib.mkOption {
                  type = sectionType;
                  default = { };
                  description = "追加到 `IMAPStore` 段的关键字，例如 `MaxSize` / `Trash` / `Flatten`。";
                };

                extraMaildirStoreOptions = lib.mkOption {
                  type = sectionType;
                  default = { };
                  description = "追加到 `MaildirStore` 段的关键字，例如 `AltMap` / `InfoDelimiter`。";
                };

                extraChannelOptions = lib.mkOption {
                  type = sectionType;
                  default = { };
                  example = lib.literalExpression ''{ MaxMessages = "1000"; Sync = [ "Pull" "New" ]; }'';
                  description = ''
                    追加到 `Channel` 段的关键字，例如 `Sync` / `MaxSize` /
                    `MaxMessages` / `Remove` / `ExpireUnread`。
                  '';
                };
              };
            }
          );
          default = { };
          example = lib.literalExpression ''
            {
              qq = {
                host = "imap.qq.com";
                user = "urie96@qq.com";
                passCmd = "rbw get 'qq imap'";
              };
            }
          '';
          description = ''
            每个属性生成 `IMAPAccount <名字>` / `IMAPStore <名字>-remote` /
            `MaildirStore <名字>-local` / `Channel <名字>` 四段。属性名就是账号名，
            也是 channel 名（`mbsync <名字>` 只同步这个账号）。
          '';
        };

        sections = lib.mkOption {
          type = wlib.types.dagOf sectionType;
          default = { };
          example = lib.literalExpression ''
            {
              "Group all" = {
                data.Channels = [ "qq" "ustc" "gmail" ];
              };
              "IMAPAccount other" = {
                before = [ "Channel other" ];
                data = {
                  Host = "imap.example.com";
                  AuthMechs = "LOGIN";
                };
              };
            }
          '';
          description = ''
            自己写的段，段头行是属性名（如 `"IMAPAccount other"`、`"Group all"`），
            值是段里的关键字（值会做引号转义，列表 = 一个关键字带多个参数，
            `null` = 不写这一行）。
            生成在 `accounts` 的所有段之后；段之间互相引用时用 `before` / `after`
            排序（`{ data = { ... }; before = [ "Channel other" ]; }`），
            因为 isync 单趟解析，被引用的段必须在前面。
          '';
        };

        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = ''
            直接追加到配置文件末尾的原始文本，用于表达 `sections` 写不出来的东西
            （注意段之间要自己空一行）。
          '';
        };

        configFile = lib.mkOption {
          type = lib.types.nullOr wlib.types.stringable;
          default = null;
          description = ''
            直接用一份现成的 isyncrc（给 `-c` 的路径），完全覆盖
            `accounts` / `sections` / `extraConfig`（生成的那份仍留在 wrapper 输出里）。
          '';
        };

        configText = lib.mkOption {
          type = lib.types.lines;
          readOnly = true;
          description = "最终写进 wrapper 输出里那份 isyncrc 的文本。";
        };
      };

      config = {
        package = lib.mkDefault pkgs.isync;

        configText =
          lib.concatStringsSep "\n" [
            "# 由 nix-wrapper-modules 生成，请勿手改（改 modules/wrappers/mbsync）。"
            "# 段之间必须留空行；解析是单趟的，引用只能出现在被引用者之后。"
            ""
            ""
          ]
          + renderedAccounts
          + renderedSections
          + config.extraConfig;

        # 和 git / vdirsyncer 一样，把配置和 wrapper 放进同一个输出，
        # 再用 `-c` 指过去，避免产物自引用（.path 是占位符，不是 .outPath）。
        constructFiles.mbsyncrc = {
          relPath = "${config.binName}rc";
          content = config.configText;
        };

        flags."--config" =
          if config.configFile != null then config.configFile else config.constructFiles.mbsyncrc.path;

        meta.description = "mbsync（isync），isyncrc 由 `accounts` / `sections` 生成，通过 `-c` 指向。";
      };
    };
}
