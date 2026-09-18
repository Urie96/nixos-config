{
  flake.nixosModules.font =
    { pkgs, ... }:
    {
      fonts.enableDefaultPackages = true;
      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
        nerd-fonts.fira-code
        maple-mono.NF-CN-unhinted
      ];

      fonts.fontconfig = {
        enable = true;
        defaultFonts = {
          serif = [
            "Noto Serif CJK SC"
            "Noto Serif"
          ];
          sansSerif = [
            "Noto Sans CJK SC"
            "Noto Sans"
          ];
          monospace = [ "FiraCode Nerd Font" ];
          emoji = [ "Noto Color Emoji" ];
        };
      };
    };

  flake.darwinModules.font =
    { pkgs, inputs', ... }:
    let
      nur = inputs'.nur-packages.packages;
    in
    {
      # List of fonts to install into /Library/Fonts/Nix Fonts.
      fonts.packages = with pkgs; [
        fira-code
        nur.fira-mono-italic
        # nerd-fonts.fira-code
        fira-mono
        nerd-fonts.symbols-only

        maple-mono.NF-CN-unhinted
      ];

      environment.systemPackages = with pkgs; [
        fontconfig
      ];

      environment.etc = {
        "fonts/fonts.conf".source = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";
        "fonts/conf.d/10-macos-font-dirs.conf".text = ''
          <?xml version="1.0"?>
          <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
          <fontconfig>
            <dir>/System/Library/Fonts</dir>
            <dir>/Library/Fonts</dir>
            <dir>~/Library/Fonts</dir>
          </fontconfig>
        '';
      };

    };

  flake.droidModules.font = { pkgs, ... }: {
    terminal.fonts =
      let
        termuxFonts = pkgs.maple-mono.NF-CN-unhinted;
      in
      {
        regular = "${termuxFonts}/share/fonts/truetype/MapleMono-NF-CN-Regular.ttf";
        bold = "${termuxFonts}/share/fonts/truetype/MapleMono-NF-CN-Italic.ttf";
        italic = "${termuxFonts}/share/fonts/truetype/MapleMono-NF-CN-Bold.ttf";
        boldItalic = "${termuxFonts}/share/fonts/truetype/MapleMono-NF-CN-BoldItalic.ttf";
      };
  };
}
