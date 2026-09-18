{
  flake.wrappers.yazi = { pkgs, ... }: {
    settings.theme = {
      mgr = {
        syntect_theme = "${pkgs.catppuccin}/bat/Catppuccin Macchiato.tmTheme";
        border_style = {
          fg = "darkgray";
        };
      };

      indicator.preview = { };

      filetype = {
        rules = [
          {
            fg = "cyan";
            mime = "image/*";
          }
          {
            fg = "yellow";
            mime = "{audio,video}/*";
          }
          {
            fg = "magenta";
            mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
          }
          {
            fg = "green";
            mime = "application/{pdf,doc,rtf}";
          }
          {
            fg = "gray";
            mime = "vfs/{absent,stale}";
          }
          {
            bg = "red";
            bold = true;
            is = "orphan";
            url = "*";
          }
          {
            bold = true;
            fg = "cyan";
            is = "link";
            url = "*";
          }
          {
            bold = true;
            fg = "yellow";
            is = "block";
            url = "*";
          }
          {
            bold = true;
            fg = "yellow";
            is = "char";
            url = "*";
          }
          {
            bold = true;
            fg = "magenta";
            is = "sock";
            url = "*";
          }
          {
            bold = true;
            fg = "green";
            is = "exec";
            url = "*";
          }
          {
            bg = "red";
            is = "dummy";
            url = "*";
          }
          {
            bg = "red";
            is = "dummy";
            url = "*/";
          }
          {
            fg = "blue";
            url = "*/";
          }
        ];
      };
    };
  };
}
