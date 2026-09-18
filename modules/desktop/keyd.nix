{
  flake.nixosModules.keyd =
    { pkgs, lib, ... }:
    {
      # keyd 全局按键映射：Super+c → Ctrl+c，Super+v → Ctrl+v
      # https://github.com/rvaiya/keyd
      services.keyd = {
        enable = true;
        keyboards = {
          default = {
            ids = [ "*" ];
            settings = {
              # meta 是 keyd 内置的 Super 修饰层（[meta:M]）。
              # 层内显式绑定的键不会再带 Super（这里就是 Ctrl+C / Ctrl+V）；
              # 层内未绑定的键仍会以 Super+key 原样透传，不影响系统级 Super 快捷键。
              meta = {
                c = "C-c";
                v = "C-v";
                backspace = "C-backspace";
                left = "C-left";
                right = "C-right";
              };
            };
          };
        };
      };

      # keyd 守护进程需要 setgid 到 keyd 组来创建 root:keyd 0660 的 socket（/var/run/keyd.socket），
      # 但 nixpkgs 默认加固（CapabilityBoundingSet 无 CAP_SETGID、SystemCallFilter 禁了 @privileged）
      # 会挡掉 setgid。这里定向放开，其余加固保留。
      systemd.services.keyd.serviceConfig = {
        CapabilityBoundingSet = lib.mkAfter [ "CAP_SETGID" ];
        SystemCallFilter = lib.mkAfter [ "setgid" ];
      };

      # keyd 守护进程会以 root:keyd 创建 /var/run/keyd.socket（0660），
      # keyd-application-mapper 需要写这个 socket 来下发 bind 命令，所以 urie 要加进 keyd 组。
      users.groups.keyd = { };
      users.users.urie.extraGroups = [ "keyd" ];

      # 按窗口聚焦动态应用 keyd 绑定（Hyprland 走 zwlr_foreign_toplevel_manager_v1）。
      systemd.user.services.keyd-application-mapper = {
        description = "keyd application mapper (per-window key bindings)";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.keyd}/bin/keyd-application-mapper";
          # 显式指定 keyd 二进制路径，避免依赖服务 PATH
          Environment = [ "KEYD_BIN=${pkgs.keyd}/bin/keyd" ];
          Restart = "on-failure";
          RestartSec = "3";
        };
      };
    };
}
