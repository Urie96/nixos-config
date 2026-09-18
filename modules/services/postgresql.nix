{
  flake.nixosModules.postgresql =
    # 如果升级nixpkgs之后postgresql-setup报错： database "postgres" has a collation version mismatch
    # 则运行：sudo -u postgres psql -d postgres
    # 1. ALTER DATABASE postgres REFRESH COLLATION VERSION;
    # 2. ALTER DATABASE template1 REFRESH COLLATION VERSION;
    {
      services.postgresql.enable = true;
      # services.postgresql.package = pkgs.postgresql_16;
      services.postgresqlBackup.enable = true;
      services.postgresqlBackup.backupAll = true;
    };
}
