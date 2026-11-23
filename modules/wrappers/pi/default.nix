{ inputs, self, ... }:
let
  m = {
    imports = [ self.homeModules.ai ];
    wrappers.pi.enable = true;
    wrappers.ai.enable = true;
  };
in
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

  flake.homeModules.pi = m;
  flake.nixosModules.pi = m;
  flake.darwinModules.pi = m;
  flake.sysModules.pi = m;
  flake.droidModules.pi = m;
}
