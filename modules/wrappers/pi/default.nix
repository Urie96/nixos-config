{ inputs, self, ... }:
{
  flake.wrappers.pi =
    { pkgs, ... }:
    let
      nur = inputs.nur-packages.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      imports = [ self.wrapperModules.pi-base ];

      settings = {
        defaultModel = "deepseek-flash";
        defaultProvider = "deepseek";
        defaultThinkingLevel = "high";
        enabledModels = [ "deepseek/deepseek-flash" ];
        packages = with nur.piExtensions; [
          "${pi-web-access}"
        ];
      };

      skills = with nur.skills; {
        inherit
          tmux
          handoff
          teach
          writing-for-agents
          grilling
          context7-cli
          ;
      };
    };

  flake.wrappers.ai = {
    imports = [ self.wrapperModules.pi-base ];

    binName = "ai";
    filesToExclude = [ "bin/pi" ];

    settings = {
      defaultModel = "deepseek-flash";
      defaultProvider = "deepseek";
      defaultThinkingLevel = "medium";
      enabledModels = [ "deepseek/deepseek-flash" ];
    };

    addFlag = [
      [
        "--system-prompt"
        ""
      ]
      "--no-tools"
      "--no-context-files"
    ];
  };

  flake.nixosModules.pi = {
    imports = [ self.nixosModules.ai ];
    wrappers.pi.enable = true;
    wrappers.ai.enable = true;
  };
  flake.darwinModules.pi = {
    imports = [ self.darwinModules.ai ];
    wrappers.pi.enable = true;
    wrappers.ai.enable = true;
  };
  flake.sysModules.pi = {
    imports = [ self.sysModules.ai ];
    wrappers.pi.enable = true;
    wrappers.ai.enable = true;
  };
  flake.droidModules.pi = {
    imports = [ self.droidModules.ai ];
    wrappers.pi.enable = true;
    wrappers.ai.enable = true;
  };
}
