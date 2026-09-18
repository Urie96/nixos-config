{
  flake.nixosModules.btrbk =
    { lib, ... }:
    {
      security.sudo.execWheelOnly = lib.mkForce false;

      services.btrbk.instances.mynixos = {
        onCalendar = "04:00:00";
        settings = {
          snapshot_preserve_min = "1d";
          snapshot_preserve = "14d";
          target_preserve = "20d 10w *m";
          volume."/mnt/btr_pool" = {
            snapshot_dir = "/snapshots";
            target = "/mnt/btr_backup";
            subvolume = {
              "@varlib" = { };
            };
          };
        };
      };
      # 备份盘（/mnt/btr_backup，fstab 中带 nofail）不在线时，不要运行 btrbk。
      # 否则挂载失败会被静默跳过，备份直接写进本机根分区，白白占用本盘空间。
      # RequiresMountsFor 让服务依赖 mnt-btr_backup.mount，未挂载则该次任务不执行。
      systemd.services."btrbk-mynixos".unitConfig.RequiresMountsFor = [ "/mnt/btr_backup" ];

      # Btrbk does not create snapshot directories automatically, so create one here.
      systemd.tmpfiles.rules = [
        "d /snapshots 0755 root root"
      ];
    };
}
