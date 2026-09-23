{
  flake.darwinModules.homebrew =
    {
      config,
      self,
      ...
    }:
    {
      nix-homebrew = {
        enable = true;
        user = config.system.primaryUser;
        # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
        # enableRosetta = true;

        # Automatically migrate existing Homebrew installations
        autoMigrate = true;
        mutableTaps = true;
        taps = {
          "homebrew/homebrew-core" = "${self.inputs.homebrew-core}";
          "homebrew/homebrew-cask" = "${self.inputs.homebrew-cask}";
        };
        trust.taps = [ "abue-ammar/tinycast" ];
      };

      homebrew = {
        enable = true;
        # taps = builtins.attrNames config.nix-homebrew.taps;
        casks = [
          # "squirrel-app"
        ];
        caskArgs.language = "zh-CN";
        onActivation.cleanup = "none";
      };
    };
}
