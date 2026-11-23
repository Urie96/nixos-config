{ lib, ... }:
let

  work-common =
    { config, self, ... }:
    {
      environment.variables = {
        WORK = "1";
      };

      # 个人身份是 modules/home/git.nix 里的 mkDefault，这里直接覆盖成公司身份
      # （原来是 wrappers.git.settings.user）。`my.mainUser.name` 在 nix-darwin
      # 那边由 modules/common/darwin.nix 从 system.primaryUser 映射过来。
      home-manager.users.${config.my.mainUser.name} = {
        imports = [ self.homeModules.codex ];

        programs.git.settings.user = {
          name = "yangrui.0";
          email = "yangrui.0@bytedance.com";
        };
      };

      wrappers.pi = {
        settings = {
          # scene 是「按机器用途覆盖 wrapper 默认值」的地方，wrapper 里那套
          # deepseek/deepseek-flash 是通用默认，这里用 mkForce 让 work 场景赢。
          defaultModel = lib.mkForce "ep-20261120164206-s7lsp";
          defaultProvider = lib.mkForce "ark";
          enabledModels = [ "ark/*" ];
        };
        models.providers.ark = {
          api = "openai-responses";
          apiKey = "$ARK_API_KEY";
          baseUrl = "https://ark-cn-beijing.bytedance.net/api/v3";
          models = [
            {
              id = "ep-20261120164206-s7lsp";
              name = "deepseek-flash";
              contextWindow = 1000000;
              input = [
                "text"
                "image"
              ];
              reasoning = true;
            }
            {
              contextWindow = 1000000;
              name = "gpt-6.2-sol";
              id = "ep-20261120145837-mv2p5";
              input = [
                "text"
                "image"
              ];
              reasoning = true;
            }
          ];
        };
      };
    };

in
{
  flake.darwinModules.work = work-common;

  flake.sysModules.work = work-common;
}
