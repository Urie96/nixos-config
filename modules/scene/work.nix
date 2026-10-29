{ lib, ... }:
let

  work-common = {
    environment.variables = {
      WORK = "1";
    };

    wrappers.git.settings.user = {
      name = lib.mkForce "yangrui.0";
      email = lib.mkForce "yangrui.0@bytedance.com";
    };

    wrappers.pi = {
      settings = {
        # scene 是「按机器用途覆盖 wrapper 默认值」的地方，wrapper 里那套
        # deepseek/deepseek-flash 是通用默认，这里用 mkForce 让 work 场景赢。
        defaultModel = lib.mkForce "ep-20261015193016-mtb6n";
        defaultProvider = lib.mkForce "ark";
        enabledModels = [ "ark/*" ];
      };
      models.providers.ark = {
        api = "openai-responses";
        apiKey = "$ARK_API_KEY";
        baseUrl = "https://ark-cn-beijing.bytedance.net/api/v3";
        models = [
          {
            id = "ep-20261015193016-mtb6n";
            name = "deepseek-flash_4";
            contextWindow = 1000000;
            input = [
              "text"
              "image"
            ];
            reasoning = true;
          }
          {
            id = "ep-20261015192956-gg59m";
            name = "deepseek-flash_2";
            contextWindow = 1000000;
            input = [
              "text"
              "image"
            ];
            reasoning = true;
          }
          {
            contextWindow = 1000000;
            name = "gpt-6-astra";
            id = "ep-20261015192942-kkvhn";
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
