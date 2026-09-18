{
  perSystem =
    {
      pkgs,
      inputs',
      self',
      ...
    }@args:
    {
      packages.notify-me = pkgs.writeShellApplication {
        name = "notify-me";
        runtimeInputs = with pkgs; [
          curl
          jq
        ];
        text = builtins.readFile ./notify-me.sh;
      };
    };
}
