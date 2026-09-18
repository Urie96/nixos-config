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
}
