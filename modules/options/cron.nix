# nix-on-droid 上的定时任务：supercronic（单个静态 Go 二进制、不需要 root、
# 不依赖 /etc/passwd）+ 已有的 runit 模块托管。
#
# 为什么不用 systemd/launchd：Android 上没有。为什么不用 sleep 循环：后面还会加
# 别的任务，cron 表达式更省事，而且日志由 svlogd 统一收集、自动轮转。
#
# 用法（机器侧）：
#   cron.jobs.pull-deploy = {
#     schedule = "17 */6 * * *";
#     command = "${...}/bin/pull-deploy";
#   };
#
# jobs 非空才会起服务（没有「开了但没任务」的状态）。时区跟随
# modules/common/droid.nix 的 time.timeZone。
#
# ── 为什么 crontab 走 /etc 而不是 store 路径 ────────────────────────────────
#
# 以前 cron-run 里写的是 supercronic 的 crontab store path（pkgs.writeText 的
# 产物），每代 generation 都不同，所以每次 activation 之后都得 `sv restart cron`
# 才能换上新配置；而 restart 会 TERM 掉 supercronic（连带影响正在跑的任务），于是
# pull-deploy 里只好塞一段「延后 5 秒、setsid 到新 session 去重启」的自我保护。
#
# 现在 crontab 放在稳定的 /etc 路径上：
#
#   /etc/supercronic-crontab -> /etc/static/supercronic-crontab -> /nix/store/…
#
# activation 只把 /etc/static 原子换向（见 nix-on-droid 的 setup-etc.sh），
# /etc/supercronic-crontab 这个路径本身不变，于是 cron-run 脚本跨 generation 完全
# 相同（store path 相同，`ln -sf` 不会触碰正在跑的 runsv），配置更新交给
# supercronic 自己 reload：
#
#   sv 2 cron        # runit 控制字符 2 == SIGUSR2
#
# supercronic 收到 SIGUSR2 只停止「调度」，然后等正在跑的任务结束后才重读 crontab；
# 它不会给任务发信号（和 SIGTERM 的 shutdown 不同）。所以从 pull-deploy 任务内部
# 触发的 reload 不会杀死 pull-deploy 自己。
#
# 几个不能踩的坑：
#   - 不能用 `sv hup`：supercronic 只 Notify 了 INT/TERM/QUIT/USR2，SIGHUP 走默认
#     动作＝直接终止进程。
#   - 不能给 `runit.services.cron.execute.control."2"` 写脚本：runit 里 control/
#     下存在同名可执行文件时会「取代」默认的信号行为。
#   - `-inotify` 在这里没用：它 watch 的是解析后的 store inode，而 nix-on-droid 只
#     换 /etc/static 的指向，那个 inode 不变，收不到任何事件（实测）。
{ ... }:
{
  flake.droidModules.common =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.cron;

      commandOf = c: if lib.isString c then c else lib.getExe c;

      crontabName = "supercronic-crontab";
      crontabPath = "/etc/${crontabName}";

      crontabText = lib.concatStringsSep "" (
        lib.mapAttrsToList (name: job: ''
          # ${name}
          ${job.schedule} ${commandOf job.command}
        '') cfg.jobs
      );

      crontabRaw = pkgs.writeText "nix-on-droid-crontab.in" crontabText;

      # 构建期用 `supercronic -test` 校验：某个 schedule 写错时 build 就失败，
      # 而不是等到 reload 时 supercronic Fatal 退出、被 runsv 反复重启（服务整个
      # 挂掉，且下一次 reload 也不会成功）。
      crontabFile = pkgs.runCommandLocal "nix-on-droid-crontab" { } ''
        ${lib.getExe pkgs.supercronic} -test ${crontabRaw}
        cp ${crontabRaw} $out
      '';

      svlogdir = config.runit.settings.environment.logdir;
      sv = "${config.runit.settings.packageWrapped}/bin/sv";
    in
    {
      options.cron.jobs = lib.mkOption {
        default = { };
        description = "定时任务：名字 → { schedule = cron 表达式；command = 要执行的命令 }。";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              schedule = lib.mkOption {
                type = lib.types.str;
                example = "17 */6 * * *";
                description = "标准 5 段 cron 表达式（分 时 日 月 周）。";
              };

              command = lib.mkOption {
                type = lib.types.either lib.types.str lib.types.package;
                description = "要执行的命令（字符串按原样写进 crontab，包则取 mainProgram）。";
              };
            };
          }
        );
      };

      config = lib.mkIf (cfg.jobs != { }) {
        # /etc/<name> 是稳定路径，内容随 generation 原子换向。
        environment.etc.${crontabName}.source = crontabFile;

        runit.services.cron = {
          enable = true;
          svlogd.enable = true;

          execute = {
            # 写死稳定路径：这一行跨 generation 不变，cron-run 的 store path 也就
            # 不变。改 crontab 不会碰到正在跑的 runsv（不再需要 restart）。
            run = pkgs.writeScriptBin "cron-run" ''
              #!${pkgs.runtimeShell}
              exec ${lib.getExe pkgs.supercronic} -passthrough-logs ${crontabPath}
            '';

            # 日志写到 $logdir/cron。runit 模块的默认 log/run 是 `svlogd -tt .`
            # （cwd = service 的 log 目录），日志会散落在 $svdir/<name>/log 里，
            # 和 $logdir 下的其它日志不在一起。
            log.run = pkgs.writeScriptBin "cron-log-run" ''
              #!${pkgs.runtimeShell}
              exec ${config.runit.settings.packageWrapped}/bin/svlogd -tt ${svlogdir}/cron
            '';
          };
        };

        # 必须放在 activationAfter：crontab 的换向是 build.activation.setUpEtc 做的，
        # 而 activation 的 key 按字母序执行（`runsvdir` < `setUpEtc`），所以 reload
        # 要晚于它，否则读到的是上一代 crontab。
        # 服务没起来时 `sv 2` 会失败，忽略即可（runsv 起来后读的就是新文件）。
        # 注意这里只 reload、不 restart：cron-run 自身变化（supercronic 版本升级、
        # 命令行改动）不会自动生效，需要重启会话或手动 `sv restart cron`。
        build.activationAfter.cronReload = ''
          $DRY_RUN_CMD ${sv} 2 cron || true
        '';
      };
    };
}
