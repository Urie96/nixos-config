{
  # 原来这里是 modules/wrappers/git.nix 里的 nix-wrapper-modules wrapper
  # （用 GIT_CONFIG_GLOBAL 指到 wrapper 输出里的 gitconfig）。改成 home-manager
  # 的 programs.git 之后，配置写到 $XDG_CONFIG_HOME/git/config —— 这是 git 默认
  # 读取的全局配置，不需要再包一层；包由 home profile 提供，PATH 上排在
  # system 的 git-minimal 之前，也就不需要 hiPrio 了。
  #
  # 由 flake.homeModules.common import（见 modules/home/home.nix），
  # 所以每台开了 home-manager 的机器的主用户都会有一份。
  flake.homeModules.git =
    {
      lib,
      pkgs,
      ...
    }:
    {
      programs.git = {
        enable = true;

        # 和原来的 wrapper 一致，用 gitMinimal（没有 svn/gui/send-email）。
        package = pkgs.gitMinimal;

        # 全局 ignore：home-manager 写到 $XDG_CONFIG_HOME/git/ignore，也就是
        # git 默认的 core.excludesFile 位置，不用再显式指定。
        ignores = [
          "*~"
          "*.swp"
          "*.swo"
          ".DS_Store"
          ".gdb_history"
          ".direnv.*"
          ".direnv"
          "tags"
          ".mypy_cache/"
          ".pytest_cache/"
          ".ruff_cache/"
          ".cache/clangd"
          ".terraform/"

          # Devenv
          ".devenv*"
          "devenv.local.nix"
        ];

        settings = {
          core = {
            pager = "delta";
            editor = "nvim";
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

          # 个人身份是默认值，work 场景（modules/scene/work.nix）直接覆成公司身份。
          user = {
            name = lib.mkDefault "yangrui";
            email = lib.mkDefault "lubui.com@gmail.com";
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
