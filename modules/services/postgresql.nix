{ self, ... }:
{
  flake.nixosModules.postgresql =
    # glibc 升级（nixpkgs 更新）后，libc collation 的版本号会变，而 pg_database.datcollversion
    # 还是旧值。表现：连接时报 WARNING "has a collation version mismatch"；
    # postgresql-setup 里 CREATE DATABASE 报 ERROR template database "template1" has a collation
    # version mismatch → postgresql.target 失败 → 依赖它的服务（immich、nixbot…）全部 dependency failed。
    # 处理步骤：
    # 1. 逐个库刷新版本号（template0 不要动）：
    #    sudo -u postgres psql -Atc "select datname from pg_database where datname <> 'template0'" \
    #      | while read -r db; do
    #          sudo -u postgres psql -d "$db" -c "ALTER DATABASE \"$db\" REFRESH COLLATION VERSION;"
    #        done
    # 2. 重建各库索引（排序规则变了，旧 btree 可能不再有序）：
    #    ... | while read -r db; do sudo -u postgres psql -d "$db" -c "REINDEX DATABASE \"$db\";"; done
    # 3. sudo systemctl reset-failed postgresql-setup.service && sudo systemctl restart postgresql-setup.service
    #    然后重新 start 那些 dependency failed 的服务（immich-server、nixbot…）。
    {
      services.postgresql.enable = true;
      # services.postgresql.package = pkgs.postgresql_16;
      # 新建集群建议用 C.UTF-8 collation，避免 glibc 升级再次触发上面这个问题
      # （只对 initdb 创建的新集群生效）：
      # services.postgresql.initdbArgs = [ "--locale=C.UTF-8" ];
      services.postgresqlBackup.enable = true;
      services.postgresqlBackup.backupAll = true;
    };

  flake.sysModules.postgresql = {
    imports = [ "${self.inputs.nixpkgs.outPath}/nixos/modules/services/databases/postgresql.nix" ];
  };
}
