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

  # 安装入口：modules/base.nix 里 `imports = with self.<class>; [ pi ]` 引用。
  # 通用的 install 模块只为声明 `wrappers.pi.*` 选项，真正落地靠 enable 打开。
  flake.nixosModules.pi = {
    wrappers.pi.enable = true;
  };
  flake.darwinModules.pi = {
    wrappers.pi.enable = true;
  };
  flake.sysModules.pi = {
    wrappers.pi.enable = true;
  };
  flake.droidModules.pi = {
    wrappers.pi.enable = true;
  };
}
