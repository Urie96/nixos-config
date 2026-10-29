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
        "tui.altScreen.previousPrompt" = [ "alt+ctrl+j" ];
        "tui.altScreen.nextPrompt" = [ "alt+ctrl+l" ];
        "tui.editor.cursorRight" = [ "right" ]; # 默认还包含ctrl+f
        "tui.altScreen.search" = [ "ctrl+f" ];
        "tui.altScreen.top" = [ "alt+ctrl+i" ];
        "tui.altScreen.bottom" = [ "alt+ctrl+k" ];
      };
      themeFile = ./themes/catppuccin-mocha.json;

      settings = {
        packages = [
          "${./extensions/notify.ts}"
          "${./extensions/coding-agent-status.ts}"
        ];
      };

      models.providers = {
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
}
