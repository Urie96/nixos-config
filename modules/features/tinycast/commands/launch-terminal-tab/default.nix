{
  perSystem =
    {
      pkgs,
      inputs',
      self',
      ...
    }:
    {
      packages.launch-terminal-tab = pkgs.writeShellApplication {
        name = "launch-terminal-tab";
        runtimeInputs = with pkgs; [
          gnugrep
          coreutils
        ];
        text = builtins.readFile ./launch-terminal-tab.sh;
      };
    };
}
