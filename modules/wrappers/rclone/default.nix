{ self, ... }:
{
  flake.wrappers.rclone =
    {
      config,
      lib,
      ...
    }:
    let
      secret = name: fallback: if config.useSops then config.sops.placeholder.${name} else fallback;
    in
    {
      imports = [
        self.wrapperModules.sops
      ];

      sops.secretsFile = ./secrets.yaml;
      # 私钥默认从 $XDG_CONFIG_HOME/sops/age/keys.txt 找；也可以显式指定：
      # sops.keyFile = "/home/urie/.config/sops/age/keys.txt";

      settings = lib.mkDefault {
        openlist = {
          type = "webdav";
          url = "https://openlist.lubui.com:8443/dav/";
          user = "urie";
          vendor = "other";
          pass = secret "rclone_openlist_pass" "xxx";
        };

        aws_s3_backup = {
          type = "s3";
          provider = "AWS";
          region = "ap-east-1";
          location_constraint = "ap-east-1";
          storage_class = "DEEP_ARCHIVE";
          access_key_id = secret "rclone_aws_access_key_id" "xxx";
          secret_access_key = secret "rclone_aws_secret_access_key" "xxx";
        };

        cloud_backup = {
          type = "alias";
          remote = "aws_s3_backup:urie-backup-bucket";
        };

        google_drive = {
          type = "drive";
          client_id = "951852859220-rbpv9q1llrh7aa53fmg4ek68jd462nbd.apps.googleusercontent.com";
          scope = "drive";
          team_drive = "";
          client_secret = secret "rclone_google_drive_client_secret" "xxx";
          token = secret "rclone_google_drive_token" "xxx";
        };

        home_sftp = {
          type = "sftp";
          host = "home.lubui.com";
          user = "urie";
          key_file = "~/.ssh/id_rsa";
          shell_type = "unix";
          md5sum_command = "md5sum";
          sha1sum_command = "sha1sum";
        };

        nextcloud = {
          type = "webdav";
          url = "https://cloud.lubui.com:8443/nextcloud/remote.php/dav/files/urie/";
          vendor = "nextcloud";
          user = "urie";
          pass = secret "rclone_nextcloud_pass" "xxx";
        };
      };
    };
}
