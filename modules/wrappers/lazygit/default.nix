{
  flake.wrappers.lazygit =
    {
      pkgs,
      lib,
      ...
    }:
    let
      lazygitAction = pkgs.writeShellApplication {
        name = "lazygit-action";
        text = builtins.readFile ./lazygit-action.sh;
      };
    in
    {
      settings = {
        customCommands = [
          {
            command = "${lib.getExe lazygitAction} {{.Form.Action}}";
            context = "files";
            key = "<c-o>";
            output = "terminal";
            prompts = [
              {
                key = "Action";
                type = "menu";
                title = "Which action?";
                options = [
                  {
                    description = "Open remote in web browser";
                    name = "browser";
                    value = "";
                  }
                  {
                    description = "New merge request";
                    name = "merge request";
                    value = "mr";
                  }
                  {
                    description = "Generate AI-powered commit message";
                    name = "AI Commit";
                    value = "ai";
                  }
                ];
              }
            ];
          }
        ];

        git = {
          autoForwardBranches = "none";
          diffRenderers = [
            {
              command = "delta --dark --paging=never";
              colorArg = "always";
            }
          ];
        };

        gui = {
          language = "zh-CN";
          mainPanelSplitMode = "flexible";
          nerdFontsVersion = "3";
          shortTimeFormat = "15:04";
          timeFormat = "2006-01-02";

          theme = {
            activeBorderColor = [
              "#f5c2e7"
              "bold"
            ];
            inactiveBorderColor = [ "#a6adc8" ];
            searchingActiveBorderColor = [ "#f9e2af" ];
            optionsTextColor = [ "#89b4fa" ];
            selectedLineBgColor = [ "#313244" ];
            inactiveViewSelectedLineBgColor = [ "#6c7086" ];
            cherryPickedCommitFgColor = [ "#f5c2e7" ];
            cherryPickedCommitBgColor = [ "#45475a" ];
            markedBaseCommitFgColor = [ "#89b4fa" ];
            markedBaseCommitBgColor = [ "#f9e2af" ];
            unstagedChangesColor = [ "#f38ba8" ];
            defaultFgColor = [ "#cdd6f4" ];
          };

          authorColors."*" = "#b4befe";
        };

        keybinding = {
          stash.popStash = "p";

          universal = {
            nextItem-alt = "";
            nextTab = "L";
            prevItem-alt = "";
            prevTab = "J";
            scrollDownMain-alt1 = "";
            scrollLeft = "j";
            scrollRight = "l";
            scrollUpMain-alt1 = "";
          };
        };

        notARepository = "quit";

        os = {
          editPreset = "nvim";
          copyToClipboardCmd = "printf {{text}} | copy";
        };
      };
    };
}
