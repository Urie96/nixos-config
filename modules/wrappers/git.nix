{
  flake.wrappers.git =
    {
      pkgs,
      wlib,
      lib,
      config,
      ...
    }:
    {
      imports = [ wlib.wrapperModules.git ];

      options.ignore = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          全局 gitignore 内容（多行字符串）。内容会通过 constructFiles 生成一个
          ignore 文件，和 gitconfig 放在同一个输出里，并把 gitconfig 的
          `[core] excludesFile` 指向它。
        '';
      };

      config = {
        # 该模块同时用了顶层 options/config，其它配置必须写在 config 里
        package = pkgs.gitMinimal;

        # 和 generate 出来的 gitconfig 放在同一个 wrapper 输出目录下：
        #   ${config.binName}config -> gitconfig
        #   ${config.binName}ignore -> gitignore
        constructFiles.gitignore = {
          relPath = "${config.binName}ignore";
          content = config.ignore;
        };

        ignore = ''
          *~
          *.swp
          *.swo
          .DS_Store
          .gdb_history
          .direnv.*
          .direnv
          tags
          .mypy_cache/
          .pytest_cache/
          .ruff_cache/
          .cache/clangd
          .terraform/

          # Devenv
          .devenv*
          devenv.local.nix
        '';

        settings = {
          core = {
            pager = "delta";
            editor = "nvim";
            # 用 .path（占位符）而不是 .outPath，避免产物自引用。
            excludesFile = config.constructFiles.gitignore.path;
          };

          interactive = {
            singlekey = true;
            diffFilter = "delta --color-only";
          };

          format.signoff = true;

          color = {
            branch = true;
            diff = true;
            status = true;
          };

          push = {
            recurseSubmodules = "on-demand";
            default = "current";
            autoSetupRemote = true;
          };

          submodule.fetchJobs = 0;

          delta = {
            navigate = true;
            dark = true;
            light = false;
            "keep-plus-minus-markers" = true;
            "line-numbers" = false;
            "side-by-side" = false;
            "true-color" = "always";
            # include.path = "${inputs'.catppuccin-nix.packages.delta}/catppuccin.gitconfig";
            features = "catppuccin-mocha";
          };

          user = {
            name = "yangrui";
            email = "lubui.com@gmail.com";
          };

          gpg.format = "ssh";

          diff = {
            compactionHeuristic = true;
            renames = true;
            colorMoved = "default";
            algorithm = "histogram";
            mnemonicPrefix = true;
          };

          merge = {
            tool = "codediff";
            keepBackup = false;
            conflictstyle = "zdiff3";

            mergiraf = {
              name = "mergiraf";
              driver = "mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
            };
          };

          mergetool = {
            vimdiff.cmd = "nvim -d $LOCAL $REMOTE $MERGED -c '$wincmd w' -c 'wincmd J'";
            codediff.cmd = ''nvim "$MERGED" -c "CodeDiff merge \"$MERGED\""'';
          };

          rerere = {
            autoUpdate = true;
            enabled = true;
          };

          branch = {
            autoSetupRebase = "remote";
            autoSetupMerge = true;
            sort = "-committerdate";
          };

          pull = {
            rebase = true;
            autostash = true;
            twohead = "ort";
          };

          rebase = {
            stat = true;
            autoStash = true;
            autoSquash = true;
            updateRefs = true;
          };

          help.autocorrect = 10;

          filter.lfs = {
            clean = "git-lfs clean -- %f";
            smudge = "git-lfs smudge -- %f";
            process = "git-lfs filter-process";
            required = true;
          };

          github.user = "Urie96";

          init.defaultBranch = "main";

          credential = {
            helper = "store";
            "https://github.com".helper = "!gh auth git-credential";
            "https://gist.github.com".helper = "!gh auth git-credential";
          };

          fetch = {
            all = true;
            prune = true;
            pruneTags = true;
          };

          tag.sort = "version:refname";
        };
      };
    };
}
