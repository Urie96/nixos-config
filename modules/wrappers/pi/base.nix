{ inputs, ... }:
{
  flake.wrappers.pi-base =
    { pkgs, ... }:
    let
      piPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi.override {
        useBun = false;
      };
    in
    {
      package = piPackage;

      keybindings = {
        "app.interrupt" = [ "ctrl+c" ];
        "app.clear" = [ ];
      };
      themeFile = ./themes/catppuccin-mocha.json;

      settings = {
        # lastChangelogVersion = "0.84.3";
        packages = [
          "${./extensions/notify.ts}"
          "${./extensions/coding-agent-status.ts}"
        ];
      };

      models = {
        providers = {
          modelhub = {
            api = "openai-completions";
            apiKey = "$MODELHUB_API_KEY";
            baseUrl = "https://aidp.bytedance.net/api/modelhub/online/v2/crawl/openai/deployments/gpt_openapi";
            models = [
              {
                contextWindow = 1000000;
                id = "gpt-5.4-2026-03-05";
                input = [
                  "text"
                  "image"
                ];
                reasoning = true;
              }
              {
                contextWindow = 500000;
                id = "ali-deepseek-v4-flash";
              }
            ];
          };
          modelhub-response = {
            api = "openai-responses";
            apiKey = "$MODELHUB_API_KEY";
            baseUrl = "https://search.bytedance.net/gpt/openapi/online";
            models = [
              {
                contextWindow = 1000000;
                headers = {
                  extra = "{\"session_id\":\"$PI_SESSION_ID\"}";
                };
                id = "gpt-5.5-2026-04-24";
                input = [
                  "text"
                  "image"
                ];
                reasoning = true;
              }
            ];
          };
          yybbcode = {
            api = "openai-completions";
            apiKey = "$YYBBCODE_API_KEY";
            baseUrl = "https://yybb.dog/v1";
            headers = {
              User-Agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/237.84.2.178 Safari/537.36";
            };
            models = [
              {
                contextWindow = 1000000;
                id = "gpt-5.6-sol";
                input = [
                  "text"
                  "image"
                ];
                reasoning = true;
              }
              {
                contextWindow = 1050000;
                id = "gpt-5.6-luna";
                input = [
                  "text"
                  "image"
                ];
                reasoning = true;
              }
            ];
          };
          deepseek = {
            models = [
              {
                contextWindow = 1000000;
                id = "deepseek-flash";
                input = [
                  "text"
                  "image"
                ];
                reasoning = true;
                maxTokens = 384000;
              }
            ];

          };
        };
      };
    };
}
