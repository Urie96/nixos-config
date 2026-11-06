{
  # 推送小工具：把一段文本 POST 给本机的 apprise-server(3102)，
  # 由 config 里的 tag 决定最终落到哪个渠道（目前是 Telegram 群）。
  #
  # 用途：acme postRun 这类「shell 脚本里顺手发一条通知」的场景。
  # systemd 单元的失败告警不要用这个，走 monitoring/ 那套
  # （telegraf systemd_units -> vmalert -> alertmanager -> ntfy）。
  perSystem =
    { pkgs, ... }:
    {
      packages.notify-me = pkgs.writeShellApplication {
        name = "notify-me";
        runtimeInputs = with pkgs; [
          curl
          jq
        ];
        text = builtins.readFile ./notify-me.sh;
      };
    };
}
