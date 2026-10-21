{ self, ... }:
{
  flake.sysModules.gitea-runner =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [
        "${self.inputs.nixpkgs.outPath}/nixos/modules/services/continuous-integration/gitea-actions-runner.nix"
      ];

      # 上游模块无条件读取 config.virtualisation.{docker,podman}.enable（即使注册的
      # 全是 host 标签），system-manager 没有这两个 option，这里声明空壳保持默认 false。
      # host 模式用不到容器运行时。
      options.virtualisation = {
        docker.enable = lib.mkEnableOption "docker (placeholder needed by the gitea-actions-runner module)";
        podman.enable = lib.mkEnableOption "podman (placeholder needed by the gitea-actions-runner module)";
      };

    };

  # nix-darwin 没有 systemd，也没有 nixpkgs 的 gitea-actions-runner 模块，
  # 这里按 https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/continuous-integration/gitea-actions-runner.nix
  # 的语义移植一份 host-only 实现：
  #   - systemd 的 DynamicUser/StateDirectory -> launchd.daemons 的 UserName + 显式状态目录
  #   - ExecStartPre 里的注册逻辑 -> 启动脚本里注册完再 exec daemon
  # 容器标签（*:docker://...）需要 docker/podman，nix-darwin 没有 virtualisation.*，直接断言拒绝。
  flake.darwinModules.gitea-runner =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        all
        any
        attrValues
        concatStringsSep
        escapeShellArg
        filterAttrs
        flatten
        getExe
        hasInfix
        hasPrefix
        hasSuffix
        literalExpression
        mapAttrs'
        mapAttrsToList
        mkBefore
        mkDefault
        mkEnableOption
        mkIf
        mkOption
        mkPackageOption
        nameValuePair
        optional
        optionalAttrs
        optionalString
        optionals
        types
        ;

      cfg = config.services.gitea-actions-runner;

      settingsFormat = pkgs.formats.yaml { };

      # 空 labels 会落到 upstream 的默认 docker 标签，同样需要容器运行时。
      hasDockerScheme =
        instance: instance.labels == [ ] || any (label: hasInfix ":docker:" label) instance.labels;

      hasHostScheme = instance: any (label: hasSuffix ":host" label) instance.labels;

      tokenXorTokenFile =
        instance:
        (instance.token == null && instance.tokenFile != null)
        || (instance.token != null && instance.tokenFile == null);

      enabledInstances = filterAttrs (_: instance: instance.enable) cfg.instances;

      # NixOS 版用 systemd 的 DynamicUser 跑（临时 UID、无登录、无 passwd 常驻条目），
      # darwin 上对应的做法是一个隐藏的专用系统账号（照 nix-darwin 的 github-runner 模块），
      # 这样 CI 作业读不到主用户的 home/keychain。
      #
      # uid/gid 取 >501：nix-darwin 删除账号时只处理 uid > 501 的账号（见 modules/users/default.nix），
      # 且要避开 nix-darwin 自己占的 350（nixbld）、532/533（gitlab/github runner）；536 目前空着。
      managedUser = "_gitea-runner";
      managedGroup = "_gitea-runner";
      managedId = 536;
      usesManagedUser = any (instance: instance.user == managedUser) (attrValues enabledInstances);

      userOf = instance: config.users.users.${instance.user};

      stateDirOf =
        instance: if instance.stateDir != null then instance.stateDir else "/var/lib/gitea-runner";

      instanceDir = name: instance: "${stateDirOf instance}/${name}";

      # 日志放在外面：状态目录是 0700 的私有目录，日志给别人看的时候不用进私人目录。
      logDirOf = name: "/var/log/gitea-runner/${name}";

      # 对应 upstream 的 ExecStartPre + ExecStart：注册（token 或 labels 变了就重注册）后直接 exec daemon。
      mkStartScript =
        name: instance:
        let
          configFile = settingsFormat.generate "gitea-runner-${name}-config.yaml" instance.settings;
          dir = instanceDir name instance;
        in
        pkgs.writeShellScript "gitea-runner-${name}-start" ''
          set -eu

          export INSTANCE_DIR=${escapeShellArg dir}
          # 与 NixOS 版本一致：HOME 指向实例状态目录，注册信息和缓存都留在里面。
          export HOME="$INSTANCE_DIR"
          mkdir -p "$INSTANCE_DIR"
          cd "$INSTANCE_DIR"

          ${optionalString (instance.tokenFile != null) ''
            # tokenFile 语义与 NixOS 版本一致：一个包含 TOKEN 的环境文件。
            set -a
            . ${escapeShellArg (toString instance.tokenFile)}
            set +a
          ''}

          TOKEN_HASH_FILE="$INSTANCE_DIR/.token-hash"
          TOKEN_HASH_CURRENT="$(printf '%s' "''${TOKEN:?TOKEN is not set}" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
          TOKEN_HASH_STORED="$(cat "$TOKEN_HASH_FILE" 2>/dev/null || echo "")"
          LABELS_FILE="$INSTANCE_DIR/.labels"
          LABELS_WANTED="$(printf '%s\n' ${escapeShellArg (concatStringsSep "\n" instance.labels)} | ${pkgs.coreutils}/bin/sort)"
          LABELS_CURRENT="$(cat "$LABELS_FILE" 2>/dev/null || echo 0)"

          if [ ! -e "$INSTANCE_DIR/.runner" ] || [ "$LABELS_WANTED" != "$LABELS_CURRENT" ] || [ "$TOKEN_HASH_CURRENT" != "$TOKEN_HASH_STORED" ]; then
            # 删掉旧的注册文件，强制按新的 token/labels 重新注册。
            rm -f "$INSTANCE_DIR/.runner"

            ${getExe cfg.package} register --no-interactive \
              --instance ${escapeShellArg instance.url} \
              --token "$TOKEN" \
              --name ${escapeShellArg instance.name} \
              --labels ${escapeShellArg (concatStringsSep "," instance.labels)} \
              --config ${configFile}

            printf '%s' "$TOKEN_HASH_CURRENT" > "$TOKEN_HASH_FILE"
            printf '%s\n' "$LABELS_WANTED" > "$LABELS_FILE"
          fi

          exec ${getExe cfg.package} daemon --config ${configFile}
        '';

      mkDaemon =
        name: instance:
        nameValuePair "gitea-runner-${name}" {
          # 走到这里一定是 host 模式，hostPackages 会追加到 PATH 里。
          path = [ pkgs.coreutils ] ++ optionals (hasHostScheme instance) instance.hostPackages;
          environment = {
            HOME = instanceDir name instance;
            # 非 root 用户的 nix 要走 daemon；用 nixpkgs 的 nix 时要显式指定 CA。
            NIX_REMOTE = "daemon";
            NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          }
          # token 直接进 plist（和 NixOS 版本的环境变量一样，都在 nix store 里）。
          // optionalAttrs (instance.token != null) { TOKEN = instance.token; };
          command = mkStartScript name instance;

          serviceConfig = {
            Label = "org.nixos.gitea-runner-${name}";
            UserName = instance.user;
            WorkingDirectory = instanceDir name instance;
            RunAtLoad = true;
            # 相当于 Restart=on-failure：gitea 升级重启时 runner 会失败退出。
            KeepAlive.SuccessfulExit = false;
            ThrottleInterval = 30;
            # 构建任务不能被 io/cpu 限速（Background 会降优先级）。
            ProcessType = "Interactive";
            StandardOutPath = "${logDirOf name}/launchd-stdout.log";
            StandardErrorPath = "${logDirOf name}/launchd-stderr.log";
            # 网络变化后重连；tokenFile 变了就重起，顺便重新注册。
            WatchPaths = [
              "/etc/resolv.conf"
              "/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist"
            ]
            ++ optional (instance.tokenFile != null) (toString instance.tokenFile);
          };
        };

      # launchd 要求 StandardOutPath/WorkingDirectory 所在目录在加载 plist 前就存在，
      # 且属主是运行用户。照 nix-darwin 的 github-runner：挂在 `launchd` 这个 activation
      # script 的最前面（它已经跑完 users 创建、又还没开始加载 plist），用用户名 chown
      # 而不是数字 uid，账号建失败时会直接报错而不是默默建出一个孤立目录。
      mkActivation = name: instance: ''
        # SC2174: -p 时 -m 只作用于最深一层，这正是我们要的（父目录按 umask 建）。
        # shellcheck disable=SC2174
        ${pkgs.coreutils}/bin/mkdir -p -m u=rwx,g=,o= ${escapeShellArg (instanceDir name instance)}
        ${pkgs.coreutils}/bin/chown ${instance.user}: ${escapeShellArg (instanceDir name instance)}

        # shellcheck disable=SC2174
        ${pkgs.coreutils}/bin/mkdir -p -m u=rwx,g=rx,o= ${escapeShellArg (logDirOf name)}
        ${pkgs.coreutils}/bin/chown ${instance.user}: ${escapeShellArg (logDirOf name)}
      '';
    in
    {

      options.services.gitea-actions-runner = with types; {
        package = mkPackageOption pkgs "gitea-actions-runner" { };

        instances = mkOption {
          default = { };
          description = "Gitea Actions Runner instances.";
          type = attrsOf (submodule {
            options = {
              enable = mkEnableOption "Gitea Actions Runner instance";

              name = mkOption {
                type = str;
                example = literalExpression "config.networking.hostName";
                description = "The name identifying the runner instance towards the Gitea/Forgejo instance.";
              };

              url = mkOption {
                type = str;
                example = "https://forge.example.com";
                description = "Base URL of your Gitea/Forgejo instance.";
              };

              token = mkOption {
                type = nullOr str;
                default = null;
                description = "Plain token to register at the configured Gitea/Forgejo instance.";
              };

              tokenFile = mkOption {
                type = nullOr (either str path);
                default = null;
                description = ''
                  Path to an environment file, containing the `TOKEN` environment
                  variable, that holds a token to register at the configured
                  Gitea/Forgejo instance.
                '';
              };

              labels = mkOption {
                type = listOf str;
                example = literalExpression ''[ "native:host" ]'';
                description = ''
                  Labels used to map jobs to their runtime environment. darwin 模块只支持
                  `*:host` 标签（不提供 docker/podman），否则启用时会报断言错误。
                '';
              };

              settings = mkOption {
                description = ''
                  Configuration for gitea-runner daemon.
                  See <https://gitea.com/gitea/runner/src/branch/main/internal/pkg/config/config.example.yaml>.
                '';
                type = submodule { freeformType = settingsFormat.type; };
                default = { };
              };

              hostPackages = mkOption {
                type = listOf package;
                default = with pkgs; [
                  bash
                  coreutils
                  curl
                  gawk
                  gitMinimal
                  gnused
                  nodejs
                  wget
                ];
                defaultText = literalExpression ''
                  with pkgs; [
                    bash
                    coreutils
                    curl
                    gawk
                    gitMinimal
                    gnused
                    nodejs
                    wget
                  ]
                '';
                description = ''
                  List of packages, that are available to actions, when the runner is configured
                  with a host execution label.
                '';
              };

              user = mkOption {
                type = str;
                default = managedUser;
                description = ''
                  The user the runner runs as (launchd `UserName`), and that owns
                  {option}`stateDir`.

                  Defaults to a dedicated, hidden, non-login system account created by this
                  module (`${managedUser}`, shell `/usr/bin/false`), similar to the
                  `DynamicUser` the NixOS implementation uses. 一个实例只能用一个用户；
                  多个实例可以共享同一个专用账号。
                '';
              };

              stateDir = mkOption {
                type = nullOr str;
                default = null;
                example = "/Users/runner/.local/state/gitea-runner";
                description = ''
                  Directory holding the registration state and `HOME` of the runner.
                  Defaults to `/var/lib/gitea-runner`, with each instance in its own
                  subdirectory (`<stateDir>/<instanceName>`).
                '';
              };
            };
          });
        };
      };

      config = {
        assertions = [
          {
            assertion = all tokenXorTokenFile (attrValues enabledInstances);
            message = "Instances of services.gitea-actions-runner can have `token` or `tokenFile`, not both.";
          }
          {
            assertion = all (instance: !hasDockerScheme instance) (attrValues enabledInstances);
            message = "The darwin implementation of services.gitea-actions-runner only supports host executors: use labels ending in `:host` and drop any `*:docker://` label.";
          }
          {
            assertion = all (instance: (userOf instance).home != null) (attrValues enabledInstances);
            message = "services.gitea-actions-runner: the instance `user` must be declared in `users.users` with a `home` directory.";
          }
          # 和 nix-darwin 的 github-runner 一样：runner 依赖 nix-darwin 管理的 nix。
          {
            assertion = all (_: config.nix.enable) (attrValues enabledInstances);
            message = "services.gitea-actions-runner requires `nix.enable` on darwin.";
          }
        ];

        warnings = flatten (
          mapAttrsToList (
            _: instance:
            optional (instance.tokenFile != null && hasPrefix builtins.storeDir (toString instance.tokenFile))
              "services.gitea-actions-runner: `tokenFile` contains a secret but points to the world-readable Nix store."
          ) enabledInstances
        );

        launchd.daemons = mapAttrs' mkDaemon enabledInstances;

        # nix-darwin 只执行固定名字的 activation script，自定义名字会被忽略；
        # `launchd` 这个 script 正好在 users 建完、plist 加载之前，用它（mkBefore 放在最前面）。
        system.activationScripts.launchd.text = mkBefore (
          concatStringsSep "\n" (mapAttrsToList mkActivation enabledInstances)
        );

        # 专用运行用户：隐藏系统账号、home 与状态目录一致。
        # shell 只是元数据（账号无密码、不在 admin 组），/bin/bash 与 nix-darwin 的 runner 模块一致，
        # 避免某些动作执行 login shell 时拿到 /usr/bin/false。
        users.knownGroups = optional usesManagedUser managedGroup;
        users.knownUsers = optional usesManagedUser managedUser;
        users.groups = mkIf usesManagedUser {
          ${managedGroup} = {
            gid = mkDefault managedId;
            description = "Gitea Actions Runner service user group";
          };
        };
        users.users = mkIf usesManagedUser {
          ${managedUser} = {
            uid = mkDefault managedId;
            gid = config.users.groups.${managedGroup}.gid;
            description = "Gitea Actions Runner service user";
            isHidden = true;
            home = "/var/lib/gitea-runner";
            createHome = false;
            shell = "/bin/bash";
          };
        };
      };
    };
}
