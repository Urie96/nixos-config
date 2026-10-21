{
  flake.wrappers.vdirsyncer = {
    general.status_path = "~/.local/share/vdirsyncer/status_path";

    pairs = {
      contacts = {
        a = "local_contacts";
        b = "remote_contacts";
        collections = [ "contacts" ];
      };

      calendar = {
        a = "local_calendar";
        b = "remote_calendar";
        collections = [
          "personal"
          "work"
        ];
      };

      work_calendar = {
        a = "local_calendar";
        b = "lark_calendar";
        collections = [
          [
            "work"
            "work"
            "609B3BBF-9D91-801C-609B-3BBF9D91801C"
          ]
        ];
      };
    };

    storages = {
      remote_contacts = {
        type = "carddav";
        url = "https://caldav.lubui.com:8443";
        username = "urie";
        "password.fetch" = [
          "command"
          "rbw"
          "get"
          "caldav.lubui.com"
        ];
      };

      local_contacts = {
        type = "filesystem";
        path = "~/.contacts/";
        fileext = ".vcf";
      };

      remote_calendar = {
        type = "caldav";
        url = "https://caldav.lubui.com:8443";
        username = "urie";
        "password.fetch" = [
          "command"
          "rbw"
          "get"
          "caldav.lubui.com"
        ];
      };

      lark_calendar = {
        type = "caldav";
        url = "https://caldav.larkoffice.com";
        username = "u_unvi2037";
        "password.fetch" = [
          "command"
          "rbw"
          "get"
          "lark caldav"
        ];
      };

      local_calendar = {
        type = "filesystem";
        path = "~/.calendars/";
        fileext = ".ics";
      };
    };
  };

  # 安装入口：modules/full.nix 里 `imports = with self.<class>; [ vdirsyncer ]` 引用。
  # 通用的 install 模块只为声明 `wrappers.vdirsyncer.*` 选项，真正落地靠 enable 打开。
  flake.nixosModules.vdirsyncer = { wrappers.vdirsyncer.enable = true; };
  flake.darwinModules.vdirsyncer = { wrappers.vdirsyncer.enable = true; };
  flake.sysModules.vdirsyncer = { wrappers.vdirsyncer.enable = true; };
}
