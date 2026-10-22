let
  getBasePkgs =
    {
      inputs',
      pkgs,
      ...
    }:
    # 被包裹的包（lazygit/neovim/yazi/tmux/pi/git/fish 等）不在这里列：
    # 它们由各自 wrapper 导出的 `<class>Modules.<name>` 安装，
    # 在 modules/base.nix、modules/full.nix 里按名字引用。
    (with inputs'.nur-packages.packages; [
      copy
      pick-window
      slim-kitten
      xopen
      translate
      find-project-root
      fmt-file
      lazydeck
    ])
    ++ (with pkgs; [
      nmap
      which
      gzip
      gawk
      pkg-config
      devenv
      file
      proxychains-ng
      python3
      gh
      file
      age
      http-server
      lsof
      cookiecutter
      sqlite
      procps

      bat
      delta

      pv
      just
      argc

      fd
      fzf
      ripgrep
      rsync
      gnumake
      wget
      curl

      findutils
      coreutils
      gnused
      gnugrep
      jq
      fx
      moreutils
      bottom
      zellij
      tree
      zoxide
      nh
      pstree

      p7zip
      xz
      unzip
      gnutar
      gcc
      tea
      rbw
      pinentry-tty
      nix-tree
    ]);

  getNeovimPkgs = { pkgs, ... }: with pkgs;
    [
      marksman
      # sqls
      yaml-language-server
      lua-language-server
      gopls
      thrift-ls
      typos-lsp
      typos
      nil
      pyright
      just-lsp
      vscode-langservers-extracted
      bash-language-server
      typescript-language-server
      # rime-ls
      markdownlint-cli
      sqlfluff
      # sqls
      ruff
      imagemagick
      # ghostscript # pdf处理
      tectonic # latex 处理
      gomodifytags
      # delve
      shellcheck
      ffmpeg-headless

      nixfmt
      shfmt
      sqlfluff
      taplo
      gofumpt
      stylua
      rustfmt
      prettierd
      biome
      python3Packages.libxml2
      # golines
    ];

  getPreviewPkgs = { pkgs, ... }: with pkgs;
    [
      chafa
      poppler-utils
      librsvg
      resvg
      exiftool
      # foxtrot
      # nc2mp3
      pandoc
      libarchive
      imagemagick
      woff2
      # asciinema
      # glow
    ];

  getLanguagePkgs = { pkgs, ... }: with pkgs;
    [
      go
      cargo
      nodejs
      pnpm
      uv
    ];

  getExtraPkgs =
    {
      pkgs,
      inputs',
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
    in
    with pkgs;
    [
      # rclone/himalaya/mbsync/notmuch/mitmproxy/vdirsyncer/todoman 由各自的
      # `<class>Modules.<name>` 安装（见 modules/full.nix）。
      nur.lazydeck

      yq-go
      msmtp
      # Calendar tools
      khal
      # Contacts
      khard
      mpv
    ];

  # full = 下面所有包集的并集，顺序与上面定义一致。
  getFullPkgs =
    args:
    (getBasePkgs args)
    ++ (getNeovimPkgs args)
    ++ (getPreviewPkgs args)
    ++ (getLanguagePkgs args)
    ++ (getExtraPkgs args);
in
{
  flake.nixosModules.basePkgs =
    {
      pkgs,
      inputs',
      self',
      ...
    }@args:
    {
      environment.systemPackages =
        (getBasePkgs args)
        ++ (with pkgs; [
          netcat-openbsd
        ]);
    };

  flake.darwinModules.basePkgs =
    {
      pkgs,
      inputs',
      self',
      ...
    }@args:
    {
      environment.systemPackages = getBasePkgs args;
    };

  flake.sysModules.basePkgs =
    {
      pkgs,
      inputs',
      self',
      ...
    }@args:
    {
      environment.systemPackages = getBasePkgs args;
    };

  flake.droidModules.basePkgs =
    {
      pkgs,
      inputs',
      self',
      ...
    }@args:
    {
      environment.packages = getBasePkgs args;
    };

  flake.nixosModules.fullPkgs =
    {
      pkgs,
      inputs',
      self',
      ...
    }@args:
    {
      environment.systemPackages = getFullPkgs args;
    };

  flake.darwinModules.fullPkgs =
    {
      pkgs,
      inputs',
      self',
      ...
    }@args:
    {
      environment.systemPackages =
        (getFullPkgs args)
        ++ (with pkgs; [
          inputs'.strace-macos.packages.default
          sqlite
          # ncmdump
          qrencode
          # clipboard-jh 0.10+ 在 macOS 上用 Cocoa/ARC 编译（-fobjc-arc），但 nixpkgs 默认
          # 用 gcc15Stdenv 构建，g++ 不支持该选项导致编译失败。覆盖为 clangStdenv 恢复可用。
          (clipboard-jh.override { gcc15Stdenv = pkgs.clangStdenv; })
          netcat-gnu # openbsd mac 不可用
          android-tools
          scrcpy
        ])
        ++ (with inputs'.nur-packages.packages; [
          mac-ocr
          cliclick

          tinycast
        ]);

      homebrew.casks = [ "arc" ];
    };

  flake.sysModules.fullPkgs =
    {
      pkgs,
      inputs',
      self',
      ...
    }@args:
    {
      environment.systemPackages = getFullPkgs args;
    };

  # flake.droidModules.fullPkgs =
  #   {
  #     pkgs,
  #     inputs',
  #     self',
  #     ...
  #   }@args:
  #   {
  #     environment.packages = getFullPkgs args;
  #   };
}
