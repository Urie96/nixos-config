{
  flake.droidModules.common =
    {
      self',
      pkgs,
      inputs',
      config,
      ...
    }:
    {
      environment.sessionVariables = {
        SHELL = config.user.shell;
      };

      # runit service management (experimental, from nix-on-droid PR #540)
      runit.enable = true;
      # chroot container mode (upstream PR #538 naming); falls back to proot
      build.container.mode = "chroot";
      services.openssh.enable = true;
      services.openssh.authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWZOsC6Mx+q9rNcK/EvY5/WIJ86BDJkd/V5i+6F3qZb yangrui.0@bytedance.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILngYCsNBe3TMnnpOaxTnVoOCsJq1hq+ge5pYARiNWCC lubui.com@gmail.com"
      ];

      android-integration = {
        termux-wake-lock.enable = true;
        termux-wake-unlock.enable = true;
        termux-setup-storage.enable = true;
        termux-open-url.enable = true;
        termux-open.enable = true;
        am.enable = true;
      };

      environment.etcBackupExtension = ".bak";

      time.timeZone = "Asia/Shanghai";

      system.stateVersion = "24.05";

      terminal.properties = {
        background-overlay-color = "#80000000";
        disable-terminal-session-change-toast = true;
        # Never clear $TMPDIR on app exit: the chroot session leaves root-owned
        # files in files/usr/tmp, so the app-user cleanup fails per-file, blocks
        # the main thread for seconds (and jams GC), the app lingers stuck and
        # the next launch gets killed -> "must open twice" alternation.
        delete-tmpdir-files-older-than-x-days-on-exit = -1;
        # fullscreen = true;
      };

      terminal.colors = {
        background = "#101421";
        foreground = "#fffbf6";
        cursor = "#59e1e3";
        color0 = "#2e2e2e";
        color1 = "#eb4129";
        color2 = "#abe047";
        color3 = "#f6c744";
        color4 = "#47a0f3";
        color5 = "#7b5cb0";
        color6 = "#64dbed";
        color7 = "#e5e9f0";
        color8 = "#565656";
        color9 = "#ec5357";
        color10 = "#c0e17d";
        color11 = "#f9da6a";
        color12 = "#49a4f8";
        color13 = "#a47de9";
        color14 = "#99faf2";
        color15 = "#ffffff";
      };
    };
}
