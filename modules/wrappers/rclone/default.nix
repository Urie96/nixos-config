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
      # 必须显式列出 key：自动解析要 eval 阶段跑 sops-render --list-keys，属 IFD，已移除。
      sops.keys = [
        "rclone_openlist_pass"
        "rclone_aws_access_key_id"
        "rclone_aws_secret_access_key"
        "rclone_google_drive_client_secret"
        "rclone_google_drive_token"
        "rclone_nextcloud_pass"
      ];
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

        # Switch 上的 sys-ftpd：匿名登录、密码为空。
        # rclone 的 ftp backend 会无条件执行 obscure.Reveal(pass)，
        # pass 为空时会直接报 "input too short when revealing password"，
        # 所以这里必须放一个（已 obscure 的）占位密码。
        switch_ftp = {
          type = "ftp";
          host = "192.168.2.119";
          port = "5000";
          user = "anonymous";
          pass = "_uLeSsnqBXR3JZVoELU9BcuKBcJ7"; # rclone obscure dummy
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

  # 安装入口：modules/full.nix 里 `imports = with self.<class>; [ rclone ]` 引用。
  # 通用的 install 模块只为声明 `wrappers.rclone.*` 选项，真正落地靠 enable 打开。
  flake.nixosModules.rclone = { wrappers.rclone.enable = true; };
  flake.darwinModules.rclone = { wrappers.rclone.enable = true; };
  flake.sysModules.rclone = { wrappers.rclone.enable = true; };
}
