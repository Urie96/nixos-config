{
  flake.wrappers.todoman = {
    # 原先放在 modules/home/dotConfig/todoman/config.py，现在随 wrapper 走。
    # 注意 `startofweek` / `show_completed` 不是 todoman 的配置项（4.7 的
    # CONFIG_SPEC 里没有，写了也会被静默忽略），所以这里没有搬过来。
    settings = {
      path = "~/.calendars/*";
      default_list = "personal";
      date_format = "%Y-%m-%d";
      time_format = "%H:%M";
      default_priority = 5;
      color = "auto";
      humanize = true;
    };
  };

  # 安装入口：modules/full.nix 里 `imports = with self.<class>; [ todoman ]` 引用。
  # 通用的 install 模块只为声明 `wrappers.todoman.*` 选项，真正落地靠 enable 打开。
  flake.nixosModules.todoman = { wrappers.todoman.enable = true; };
  flake.darwinModules.todoman = { wrappers.todoman.enable = true; };
  flake.sysModules.todoman = { wrappers.todoman.enable = true; };
}
