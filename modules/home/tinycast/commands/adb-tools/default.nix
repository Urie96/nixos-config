{
  perSystem =
    {
      pkgs,
      inputs',
      self',
      ...
    }:
    {
      packages.adb-tools = pkgs.writeShellApplication {
        name = "adb-tools";
        runtimeInputs = with pkgs; [
          android-tools
          curl
          fzf
          jq
          openssh
          rbw
        ];
        text = builtins.readFile ./adb-tools.sh;
      };
    };
}
