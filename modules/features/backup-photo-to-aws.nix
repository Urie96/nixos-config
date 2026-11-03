{
  flake.nixosModules.backup-photo-to-aws =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      name = "backup-photos";
    in
    {
      systemd.timers.${name} = {
        wantedBy = [ "timers.target" ];
        after = [ "network.target" ];
        timerConfig = {
          OnCalendar = "05:00:00";
          Unit = "${name}.service";
        };
      };

      systemd.services.${name} = {
        path = with pkgs; [
          gitMinimal
          openssh
        ];
        script = ''
          set -e
          echo "backup photos starting..."

          export RCLONE_CONFIG_CLOUD_BACKUP_TYPE=s3
          export RCLONE_CONFIG_CLOUD_BACKUP_PROVIDER=AWS
          export RCLONE_CONFIG_CLOUD_BACKUP_REGION=ap-east-1
          export RCLONE_CONFIG_CLOUD_BACKUP_LOCATION_CONSTRAINT=ap-east-1
          export RCLONE_CONFIG_CLOUD_BACKUP_STORAGE_CLASS=DEEP_ARCHIVE

          export RCLONE_CONFIG_CLOUD_BACKUP_ACCESS_KEY_ID=$(cat ${config.clan.core.vars.generators.rclone_immich_aws.files.key_id.path})
          export RCLONE_CONFIG_CLOUD_BACKUP_SECRET_ACCESS_KEY=$(cat ${config.clan.core.vars.generators.rclone_immich_aws.files.access_key.path})

          ${lib.getExe pkgs.rclone} --config /dev/null \
            copy /var/lib/immich/upload cloud_backup:urie-backup-bucket/photos \
            --ignore-existing

          echo "backup photos done..."
        '';
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          User = "immich";
        };
      };

      clan.core.vars.generators.aws = {
        prompts.key_id.persist = true;
        prompts.access_key.persist = true;
        files.key_id.deploy = false;
        files.access_key.deploy = false;
      };

      clan.core.vars.generators.rclone_immich_aws = {
        dependencies = [ "aws" ];
        files.key_id.owner = "immich";
        files.access_key.owner = "immich";
        script = ''
          cp $in/aws/key_id $out/key_id
          cp $in/aws/access_key $out/access_key
        '';
      };
    };
}
