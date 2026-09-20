let
  getBasePkgs =
    {
      self',
      inputs',
      pkgs,
      ...
    }:
    (with self'.packages; [
      lazygit
      neovim
      fish
      yazi
      tmux
      pi
      # srvos 等模块会直接往 systemPackages 里塞 git-minimal，而 NixOS 的
      # system-path 用的是 ignoreCollisions = true；只有 priority 更低（数字更小）
      # 的那个才会真正落到 sw/bin/git。这里 hiPrio 保证被包裹的 git 胜出。
      (pkgs.lib.hiPrio git)
    ])
    ++ (with inputs'.nur-packages.packages; [
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
      binutils
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
      self',
      ...
    }:
    let
      nur = inputs'.nur-packages.packages;
    in
    with pkgs;
    [
      self'.packages.rclone
      self'.packages.himalaya
      self'.packages.mbsync
      self'.packages.notmuch
      self'.packages.mitmproxy
      self'.packages.vdirsyncer
      self'.packages.todoman
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
          clipboard-jh
          netcat-gnu # openbsd mac 不可用
          android-tools
          scrcpy
        ])
        ++ (with inputs'.nur-packages.packages; [
          mac-ocr
          cliclick
        ])
        ++ (with self'.packages; [
          kitty
        ]);
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
