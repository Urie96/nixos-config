{
  # work 机器上的 codex 由公司环境自行安装/更新，Nix 只负责生成
  # ~/.codex/config.toml，所以 package 传 null，不往 home profile 里装二进制。
  flake.homeModules.codex =
    { ... }:
    {
      programs.codex = {
        enable = true;
        package = null;

        # Codex 运行时会往 config.toml 里写项目信任、hook 状态等，
        # 用可变配置保留这些运行时内容，Nix 只覆盖下面声明的字段。
        mutableSettings = true;

        settings = {
          model = "ep-20261120145837-mv2p5"; # gpt-6.2-sol
          model_provider = "ark";
          model_context_window = 1000000;
          model_auto_compact_token_limit = 500000;
          model_reasoning_effort = "xhigh";
          plan_mode_reasoning_effort = "xhigh";
          sandbox_mode = "danger-full-access";
          approval_policy = "on-request";
          suppress_unstable_features_warning = true;

          features = {
            # herdr 的 codex hook 依赖这个开关。
            hooks = true;
            daemon_auto_start = false;
          };

          model_providers.ark = {
            name = "Ark";
            base_url = "https://ark-cn-beijing.bytedance.net/api/v3";
            env_key = "ARK_API_KEY";
            wire_api = "responses";
            request_max_retries = 50;
            stream_max_retries = 50;
          };
        };
      };
    };
}
