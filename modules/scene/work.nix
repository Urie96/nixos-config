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
      defaultModel = "deepseek-flash";
      defaultProvider = "deepseek";
      enabledModels = [ "ark/*" ];
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
