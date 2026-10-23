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
        # curl 用于探测自建实例是 Gitea/Forgejo 还是 GitLab
        runtimeInputs = [ pkgs.curl ];
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
            authorColors."*" = "#b4befe";
          };
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

  # 安装入口：modules/base.nix 里 `imports = with self.<class>; [ lazygit ]` 引用。
  # 通用的 install 模块只为声明 `wrappers.lazygit.*` 选项，真正落地靠 enable 打开。
  flake.nixosModules.lazygit = { wrappers.lazygit.enable = true; };
  flake.darwinModules.lazygit = { wrappers.lazygit.enable = true; };
  flake.sysModules.lazygit = { wrappers.lazygit.enable = true; };
  flake.droidModules.lazygit = { wrappers.lazygit.enable = true; };
}
