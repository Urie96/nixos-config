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

      crontab = pkgs.writeText "nix-on-droid-crontab" (
        lib.concatStringsSep "" (
          lib.mapAttrsToList (name: job: ''
            # ${name}
            ${job.schedule} ${commandOf job.command}
          '') cfg.jobs
        )
      );
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
        runit.services.cron = {
          enable = true;
          # 任务输出 + supercronic 自己的日志都进 $logdir/cron，由 svlogd 轮转。
          svlogd.enable = true;
          execute.run = pkgs.writeScriptBin "cron-run" ''
            #!${pkgs.runtimeShell}
            exec ${lib.getExe pkgs.supercronic} -passthrough-logs ${crontab}
          '';
        };
      };
    };
}
