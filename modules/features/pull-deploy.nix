# 拉取式自动部署（客户端）：非局域网机器自己定时检查并切换。
#
# 服务端见 modules/ci.nix 的 mkPull：main push 之后 nixbot 会把每台机器的目标
# toplevel 写成纯文本文件 https://cache.lubui.com:8443/desired-state/<机器名>
# （内容就是 store path）。这里的三台机器各自按周期：
#
#   1. 拉自己那个文件（拿不到就当没事发生，下个周期再试）；
#   2. 和「当前 system」比较 —— 只是 readlink -f 一个固定的 profile/gcroot 链接；
#   3. 不一致就 `nix build --no-link <outPath>` 拉闭包（并行替代），再用该
#      generation 自带的命令激活。
#
# 全程不做 nix 求值、不碰 git，也不需要 JSON 解析：机器只需要能访问
# cache.lubui.com。
#
# 为什么用 `nix build <store path>` 而不是 `nix copy --from`：
#   · 它走的是 substitution goal，按 `max-substitution-jobs`（默认 16）并行拉 NAR，
#     而 `nix copy` 是逐 path 串行拷；
#   · 显式给 store path 时不受派生的 `allowSubstitutes = false` 影响（这一点实测过：
#     带 allowSubstitutes/preferLocalBuild 的派生，删掉后仍能从 file:// 缓存被
#     `nix build` 替代回来），所以 NixOS / system-manager / nix-on-droid 这些把
#     toplevel 标成 allowSubstitutes = false 的目标也照样能拉；
#   · 缓存里万一真的没有，它会退化成在本地构建，而不是直接失败。
# darwin 多一个 `--profile`：拉下来的同时把它登记成当前 profile。
{ self, ... }:
let
  # 三个 class 共用的选项。机器名显式写（devbox / work-macbook / nix-on-droid），
  # 不猜 hostname：清单的 key 就是它。
  commonOptions =
    { lib, config, ... }:
    {
      options.pullDeploy = {
        enable = lib.mkEnableOption "由 CI 发布的 desired-state 清单驱动的拉取式部署";

        machine = lib.mkOption {
          type = lib.types.str;
          description = "机器名：既是 modules/ci.nix 里 mkPull 的第一个参数，也是清单文件名。";
        };

        stateUrl = lib.mkOption {
          type = lib.types.str;
          default = "${config.pullDeploy.cacheUrl}/desired-state/${config.pullDeploy.machine}";
          defaultText = lib.literalExpression ''"''${config.pullDeploy.cacheUrl}/desired-state/''${config.pullDeploy.machine}"'';
          description = "该机器的期望 toplevel 地址（纯文本 store path）。";
        };

        cacheUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://cache.lubui.com:8443";
          description = ''
            home-server 上的缓存/文件服务（harmonia + desired-state）。
            `stateUrl` 默认由它拼出，同时也当 `nix build` 的 substituter 前缀用。
          '';
        };
      };
    };

  # 三个 class 共用的脚本；deployShell 是各平台「拿 outPath 激活」的那几行。
  #
  # 脚本无状态：比较结果是当前 system 的纯函数，部署本身幂等，失败就等下一个
  # 周期（防重复靠调度器自己：systemd 同一个 oneshot 不会并发启动，launchd 同一个
  # job 也不会，只有 cron 需要显式加锁）。所以只有 droid 传 lock。
  mkPullDeploy =
    {
      pkgs,
      machine,
      stateUrl,
      current,
      lock ? null,
      extraInputs ? [ ],
      deployShell,
    }:
    let
      inherit (pkgs) lib;

      # supercronic 是 cron 语义，可能在上一次还没跑完时再起一个，所以只有它需要锁。
      # 用 flock 而不是自己维护状态文件：进程一死锁自动释放。
      lockSetup = lib.optionalString (lock != null) ''
        mkdir -p "$(dirname '${lock}')"
        exec 9>'${lock}'
        if ! flock -n 9; then
          echo "上一次 pull-deploy 还在跑，跳过这一轮"
          exit 0
        fi
      '';
    in
    pkgs.writeShellApplication {
      name = "pull-deploy";
      runtimeInputs = [
        pkgs.curl
        pkgs.coreutils
        pkgs.nix
      ]
      ++ extraInputs;
      text = ''
        state_url='${stateUrl}'
        current='${current}'

        ${lockSetup}

        if ! want=$(curl -fsSL --retry 2 "$state_url"); then
          echo "取不到 $state_url，保持现状" >&2
          exit 0
        fi

        # 文件里只有一个 store path（可能带结尾换行，命令替换已剥掉）。
        case "$want" in
          /nix/store/*) ;;
          *)
            echo "$state_url 的内容不像 store path：$want" >&2
            exit 0
            ;;
        esac

        have=$(readlink -f "$current" 2>/dev/null || true)
        if [ "$want" = "$have" ]; then
          exit 0
        fi

        echo "==> ${machine}: $have -> $want"
        ${deployShell}

        after=$(readlink -f "$current" 2>/dev/null || true)
        if [ "$after" != "$want" ]; then
          echo "激活后 $current 指向 $after，与清单的 $want 不一致" >&2
          exit 1
        fi
        echo "==> ${machine}: 已切换到 $want"
      '';
    };
in
{
  # ── nix-darwin（work-macbook）────────────────────────────────────────
  #
  # 用 LaunchDaemon 而不是 user agent：nix build --profile 和 activate 都要 root。
  # 后台激活会重启部分 launchd 服务，属预期行为。
  flake.darwinModules.pull-deploy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.pullDeploy;

      pullDeploy = mkPullDeploy {
        inherit pkgs;
        inherit (cfg) machine stateUrl;
        # profile 就是 activate-system 开机时读的那个链接。
        current = config.system.profile;
        deployShell = ''
          # toplevel 是可替代的：顺便用 --profile 把它登记成当前 profile。
          nix build --no-link --profile '${config.system.profile}' "$want"
          # activate 自己会更新 /run/current-system 和
          # /nix/var/nix/gcroots/current-system，不用等 activate-system。
          # 这个版本的 activate-user 已标 deprecated，root 直接跑不需要 SUDO_USER。
          "$want/sw/bin/darwin-rebuild" activate
        '';
      };
    in
    {
      imports = [ commonOptions ];

      options.pullDeploy.interval = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3600;
        description = "检查间隔（秒，launchd StartInterval）。";
      };

      config = lib.mkIf cfg.enable {
        # launchd 不会同时跑同一个 job 的两个实例，所以不需要 flock。
        launchd.daemons.pull-deploy = {
          serviceConfig = {
            ProgramArguments = [ "${pullDeploy}/bin/pull-deploy" ];
            StartInterval = cfg.interval;
            RunAtLoad = true;
            EnvironmentVariables = {
              HOME = "/var/root";
              PATH = "/nix/var/nix/profiles/system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
            };
            StandardOutPath = "/var/log/pull-deploy.log";
            StandardErrorPath = "/var/log/pull-deploy.log";
          };
        };
      };
    };

  # ── system-manager（devbox）──────────────────────────────────────────
  flake.sysModules.pull-deploy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.pullDeploy;

      pullDeploy = mkPullDeploy {
        inherit pkgs;
        inherit (cfg) machine stateUrl;
        current = "/nix/var/nix/gcroots/system-manager-current";
        deployShell = ''
          nix build --no-link "$want"
          # 等价于 `system-manager switch` 的后两步，但用的是新 generation 自带的
          # engine（避免「旧 engine 激活新格式 generation」）。register 内部裸调
          # nix-env，所以上面的 runtimeInputs 必须带 nix。
          "$want/bin/system-manager-engine" register --store-path "$want"
          "$want/bin/system-manager-engine" activate --store-path "$want"
        '';
      };
    in
    {
      imports = [ commonOptions ];

      options.pullDeploy.intervalMinutes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 30;
        description = "检查间隔（分钟，systemd OnUnitActiveSec）。";
      };

      config = lib.mkIf cfg.enable {
        # systemd 对已经在跑的 oneshot 再触发 start 是 no-op，不会并发，不需要锁。
        systemd.services.pull-deploy = {
          script = "${pullDeploy}/bin/pull-deploy";
          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
        };

        systemd.timers.pull-deploy = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "10min";
            OnUnitActiveSec = "${toString cfg.intervalMinutes}min";
            RandomizedDelaySec = "5min";
          };
        };
      };
    };

  # ── nix-on-droid ─────────────────────────────────────────────────────
  #
  # 任务本身交给 modules/features/cron.nix（supercronic + runit），这里只声明一个
  # cron job。注意会话必须在（app 开着 + termux-wake-lock），新的 activation 也要
  # 下一个 session 才完全生效。
  flake.droidModules.pull-deploy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.pullDeploy;

      pullDeploy = mkPullDeploy {
        inherit pkgs;
        inherit (cfg) machine stateUrl;
        current = "/nix/var/nix/profiles/nix-on-droid";
        # cron 语义可能重入；flock 在 util-linux 里（Android 也是 Linux）。
        lock = "${config.user.home}/.local/state/pull-deploy.lock";
        extraInputs = [ pkgs.util-linux ];
        deployShell = ''
          # 拉闭包（并行替代；activationPackage 的 allowSubstitutes = false
          # 只影响「经由派生去构建」的路径，不影响显式 store path）。
          nix build --no-link "$want"
          # activate 自己会 nix-env --profile /nix/var/nix/profiles/nix-on-droid --set。
          "$want/activate"
          # 新 generation 的 crontab 是新的 store path，而 supercronic 是长驻进程，
          # 要重启才会用上。放到新 session 里并延后几秒：直接重启会把正在跑这次任务
          # 的 supercronic（以及它底下这个脚本）一起杀掉，后面的回验就白跑了。
          setsid sh -c 'sleep 5; ${config.runit.settings.packageWrapped}/bin/sv restart cron' >/dev/null 2>&1 &
        '';
      };
    in
    {
      # 不再显式 import cron 的模块：它已经并进 droidModules.common（
      # modules/options/cron.nix），而 common 由 droidModules.base/full 带入；
      # 重复 import 会报「option 已经声明过」。
      imports = [ commonOptions ];

      options.pullDeploy.schedule = lib.mkOption {
        type = lib.types.str;
        default = "17 */6 * * *";
        description = "cron 表达式（见 modules/features/cron.nix）。";
      };

      config = lib.mkIf cfg.enable {
        cron.jobs.pull-deploy = {
          schedule = cfg.schedule;
          command = "${pullDeploy}/bin/pull-deploy";
        };
      };
    };
}
