{
  lib,
  ...
}:
{
  # Tinycast 的声明式配置：`~/.config/tinycast/settings.json` + 自定义命令。
  #
  # 两半的形态刻意不同：
  #   - settings.json 是 App 自己的产物，以 /nix/store 软链的形式存在，所以 Nix 是严格权威：
  #     App 在 UI 里改的值会在下次启动被这份文件盖回去（写穿软链会撞只读 store，只报一次
  #     `settings.json: couldn't be saved`，内容不会坏——它先写临时文件再 rename）；
  #   - 自定义命令**不进** settings.json（内容永不进文件的硬约束），只能整段写进 UserDefaults
  #     的 `customCommands` 键。这一段没有文件监听，所以内容变了会顺手把正在跑的 App 优雅
  #     退出、再按 login item 拉起来；settings.json 不需要重启（App 自己 watch，150 ms 内生效）。
  #
  # 用法（机器侧，只写差异）：
  #
  #   home-manager.users.<user> = {
  #     imports = [ self.homeModules.tinycast ];
  #     programs.tinycast = {
  #       enable = true;
  #       settings.general.language = "en";        # 深度覆盖 ./settings.json
  #       commands = [                             # 追加
  #         {
  #           name = "Rebuild";
  #           runtimeInputs = [ pkgs.nix ];
  #           text = "nixos-rebuild build --flake ~/nixos-config";
  #         }
  #       ];
  #     };
  #   };
  flake.homeModules.tinycast =
    # `lib` 取这里的参数而不是外层：只有 Home Manager 注入的 lib 才带 `lib.hm.dag`。
    {
      config,
      inputs',
      lib,
      pkgs,
      self',
      ...
    }:
    let
      cfg = config.programs.tinycast;

      nur = inputs'.nur-packages.packages // self'.packages;

      # copyApps（stateVersion ≥ 25.11 的默认）把 bundle 原样拷到这里；自动重启时用它定位。
      appPath = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}/Tinycast.app";

      defaultSettings = builtins.fromJSON (builtins.readFile ./settings.json);

      # 默认表是「裸」attrset（没走 option 的默认值），这里手工补齐同一套默认值。
      commandDefaults = {
        runtimeInputs = [ ];
        arguments = [ ];
        showsOutput = false;
        loadsShellEnvironment = false;
        requiresConfirmation = false;
        showsConfirmation = false;
        workingDirectory = null;
        id = null;
      };

      effectiveCommands = map (c: commandDefaults // c) cfg.commands;
      effectiveSettings = lib.recursiveUpdate defaultSettings (
        if cfg.settings != null then cfg.settings else { }
      );

      # macOS 自带的 /usr/bin 工具没有 nix 包。用一个只放软链的包把它们变成 runtimeInputs，
      # 这样 `inheritPath = false` 之后 PATH 仍然是完整的，脚本正文不必改写成绝对路径。
      systemTools = pkgs.runCommandLocal "tinycast-macos-tools" { } ''
        mkdir -p $out/bin
        for tool in open pbcopy pbpaste osascript say lsappinfo; do
          ln -s /usr/bin/$tool $out/bin/$tool
        done
      '';

      # id 从名字派生（UUIDv8），落成小写。快捷键、别名、排序、favorite 全挂在这个 id 上，
      # 所以改名等于换一条命令：真要改名时用 `id = "<旧 uuid>";` 把旧值钉住。
      uuidOf =
        name:
        let
          hex = builtins.hashString "sha256" "tinycast/custom-command/${name}";
          part = start: len: builtins.substring start len hex;
        in
        "${part 0 8}-${part 8 4}-8${part 13 3}-a${part 17 3}-${part 20 12}";

      # kebab 化的包名：`lib.getExe` 拼出来的路径会被 zsh 直接当词解析，不能带空格。
      slugOf = name: "tinycast-" + lib.replaceStrings [ " " ] [ "-" ] (lib.toLower name);

      argumentType = lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "参数名，显示在启动器的行内输入框上。";
          };
          isOptional = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "可选参数留空也能提交；必填参数为空时 ↵ 不提交。";
          };
        };
      };

      commandType = lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "启动器里显示的名字；同时也是 id 的派生来源。";
          };
          text = lib.mkOption {
            type = lib.types.lines;
            description = ''
              脚本正文，不写 shebang（由 nix bash 提供），参数用 `$1` `$2`。
              值由 App 以位置参数交给 zsh，永远不会拼进命令文本。
            '';
          };
          runtimeInputs = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "脚本里用到的包，会被前置进脚本内的 PATH。";
          };
          arguments = lib.mkOption {
            type = lib.types.listOf argumentType;
            default = [ ];
            description = "最多 3 个，`$1` 起。";
          };
          showsOutput = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "捕获输出并在窗口里流式显示（跑在伪终端上，有颜色）。";
          };
          loadsShellEnvironment = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "让 zsh 以 `-i` 启动，从而加载 `.zshrc`；nix 里钉死依赖时不需要。";
          };
          requiresConfirmation = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          showsConfirmation = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          workingDirectory = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "null 表示 `$HOME`；给了目录就必须存在，否则这条命令直接失败。";
          };
          id = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "显式 UUID；改名时用它把快捷键/别名/排序钉在旧值上。";
          };
        };
      };

      toRecord =
        c:
        let
          slug = slugOf c.name;
          package = pkgs.writeShellApplication {
            name = slug;
            runtimeInputs = c.runtimeInputs ++ [
              systemTools
              pkgs.bash
            ];
            text = ''
              set -euo pipefail

              ${c.text}
            '';
            meta.mainProgram = slug;
            # 正文自带 `set -euo pipefail`，这里不再重复注入。
            bashOptions = [ ];
            # 老脚本，不拿 shellcheck 当门禁。
            checkPhase = "";
            # PATH 只来自 runtimeInputs，不从登录 shell 漏进来。
            inheritPath = false;
          };
        in
        {
          command = ''${lib.getExe package} "$@"'';
          id = if c.id != null then c.id else uuidOf c.name;
          inherit (c)
            name
            arguments
            showsOutput
            loadsShellEnvironment
            requiresConfirmation
            showsConfirmation
            workingDirectory
            ;
        };

      records = map toRecord effectiveCommands;

      # 落盘前排成人类可读的 JSON（App 自己也是两空格缩进、键排序），方便 diff。
      settingsRaw = pkgs.writeText "tinycast-settings.raw.json" (builtins.toJSON effectiveSettings);
      settingsJSON =
        pkgs.runCommandLocal "tinycast-settings.json"
          {
            nativeBuildInputs = [ pkgs.jq ];
          }
          ''
            jq -S . ${settingsRaw} > $out
          '';

      commandsJSON = pkgs.writeText "tinycast-custom-commands.json" (builtins.toJSON records);

      # `defaults write -data` 要十六进制：构建期把文件翻成 hex，激活脚本只负责搬运。
      commandsHex = pkgs.runCommandLocal "tinycast-custom-commands.hex" { } ''
        ${lib.getExe' pkgs.coreutils "od"} -An -tx1 -v ${commandsJSON} | ${lib.getExe' pkgs.coreutils "tr"} -d ' \n' > $out
      '';
    in
    {
      options.programs.tinycast = {
        enable = lib.mkEnableOption "Tinycast 的声明式配置（settings.json + 自定义命令）" // {
          default = true;
        };

        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = nur.tinycast;
          description = ''
            要装进 home 的 Tinycast 包。Home Manager 在 darwin 上把它放进
            `~/Applications/Home Manager Apps/`（stateVersion ≥ 25.11 走 copyApps，是实体
            拷贝，Spotlight 能索引，代价是激活时需要「App 管理」权限）。null = 不装。
          '';
        };

        domain = lib.mkOption {
          type = lib.types.str;
          default = "com.tinycast.app";
          description = "UserDefaults 的域；本文档用的是稳定通道，Dev 构建是 com.tinycast.app.dev。";
        };

        settings = lib.mkOption {
          type = lib.types.nullOr lib.types.attrs;
          default = null;
          description = ''
            settings.json 的深度覆盖，只写要改的键（`general.language = "en"`）。
            null 表示直接用仓库里的 ./settings.json。
          '';
        };

        commands = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf commandType);
          default = null;
          description = "整个替换命令表";
        };

        restart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "命令内容变化后，是否自动优雅退出并重新拉起正在运行的 Tinycast。";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf (cfg.package != null && pkgs.stdenv.hostPlatform.isDarwin) {
          home.packages = [ cfg.package ];
        })

        (lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
          # 软链到 /nix/store：Nix 是严格权威，App 自己保存会撞只读 store 并报一次 HUD。
          home.file.".config/tinycast/settings.json".source = settingsJSON;

          # 自定义命令没有文件监听，只有重启 App 才读得到；顺带在写入后自动重启。
          home.activation.tinycastCustomCommands = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                      tinycastPlist="$HOME/Library/Preferences/${cfg.domain}.plist"

                      # plutil 把这段 Data 打成 base64，和 payload 的 base64 直接比，没变就什么都不做
                      # （每次 switch 都重启 App 是不能接受的）。
                      tinycastCurrent=$(/usr/bin/plutil -extract customCommands raw -o - "$tinycastPlist" 2>/dev/null | tr -d '\n' || true)
                      tinycastWanted=$(${lib.getExe' pkgs.coreutils "base64"} -w0 < ${commandsJSON})

                      if [ "$tinycastCurrent" != "$tinycastWanted" ]; then
                        # 这一段整体是 best-effort：HM 的 activate 带 `set -eu -o pipefail`，任何没被兜住的
                        # 非零返回都会把整个 switch 拖死。上一次就是这么挂的：app 退出之后 launchd 里查不到
                        # label，`grep` 返回 1，激活在“重新拉起”之前就中断，App 留在关闭状态。
                        run /usr/bin/defaults write ${cfg.domain} customCommands -data "$(cat ${commandsHex})" \
                          || echo "tinycast: 写入 customCommands 失败，这一次没生效"

            ${lib.optionalString cfg.restart ''
              if ! [[ -v DRY_RUN ]] && /usr/bin/pgrep -x Tinycast > /dev/null 2>&1; then
                # 退出必须是 Apple Event：SIGTERM 绕过 applicationShouldTerminate（笔记草稿的
                # 300ms debounce）和 applicationWillTerminate（Hyper key 的 caps 重映射不会归还）。
                if /usr/bin/osascript -e 'tell application id "${cfg.domain}" to quit' 2>/dev/null; then
                  for _ in {1..15}; do
                    /usr/bin/pgrep -x Tinycast > /dev/null 2>&1 || break
                    /bin/sleep 0.2
                  done
                fi

                if /usr/bin/pgrep -x Tinycast > /dev/null 2>&1; then
                  echo "tinycast: 自定义命令已写入，但退出请求被拒绝（多半是没授权自动化）；手动重启 Tinycast 才会生效"
                else
                  # 先试 login item 的 launchd job：`open` 算“用户启动”，AppCore 会顺手弹启动器。
                  # App 换过路径时 label 可能还不存在，所以下面要有退路。
                  tinycastJob=$(
                    /bin/launchctl print "gui/$(id -u)" 2>/dev/null \
                      | /usr/bin/grep -o 'application\.com\.tinycast\.app\.[0-9.]*' \
                      | /usr/bin/head -1 || true
                  )
                  if ! { [ -n "$tinycastJob" ] && /bin/launchctl kickstart "gui/$(id -u)/$tinycastJob"; }; then
                    # 按路径打开最可靠；刚 rsync 进来的副本可能还没进 LaunchServices 索引，
                    # 所以 `open -b` 只能当最后一条。
                    /usr/bin/open ${lib.escapeShellArg appPath} 2>/dev/null \
                      || /usr/bin/open -b ${cfg.domain} 2>/dev/null \
                      || echo "tinycast: 没能自动拉起，手动开一下；App 换了路径，顺手把「登录时启动」重新打开"
                  fi
                fi
              fi
            ''}          fi
          '';
        })
      ];
    };
}
