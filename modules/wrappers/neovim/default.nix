{ inputs, ... }:
{
  flake.wrappers.neovim =
    {
      wlib,
      config,
      pkgs,
      lib,
      ...
    }:
    let
      flatnvim = inputs.nur-packages.packages.${pkgs.stdenv.hostPlatform.system}.flatnvim;

      # nvim-dap 源码改为从 GitHub 镜像获取(作者在 codeberg/github 同步推送, rev 一致),
      # 避免 Codeberg 对本机出口 IP 限流导致 fetch 失败。
      # 用 vimPlugins.extend 覆盖: 依赖 nvim-dap 的插件(nvim-dap-ui)也会惰性指向覆盖后的版本。
      vimPlugins = pkgs.vimPlugins.extend (
        self: super: {
          nvim-dap = super.nvim-dap.overrideAttrs (old: {
            src = pkgs.fetchFromGitHub {
              owner = "mfussenegger";
              repo = "nvim-dap";
              inherit (old.src) rev hash;
            };
          });
          nvim-lint = super.nvim-lint.overrideAttrs (old: {
            src = pkgs.fetchFromGitHub {
              owner = "mfussenegger";
              repo = "nvim-lint";
              inherit (old.src) rev hash;
            };
          });
        }
      );
    in
    {
      # settings.compile_generated_lua = false;

      imports = [ wlib.wrapperModules.neovim ];

      package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.neovim;

      # 关掉 ruby provider host（默认是开着的）。原因不是「不需要 ruby」这么简单：
      # 上游 nvim 模块里 `hosts.ruby` 的默认值
      #   gemdir = "${pkgs.path}/pkgs/applications/editors/neovim/ruby_provider"
      # 会把 `pkgs.path` 这个 path 值插值成字符串，nix 于是走 copyPathToStore，
      # 把整份 nixpkgs 以 `<hash>-<nixpkgs store path basename>` 的名字再拷进 store
      # （约 230 MB，且没有任何 GC root）。这份拷贝被 GC 掉之后，任何再走到这里的求值
      # 都会以 `path '/nix/store/…-fkrgkr…-source' is not valid` 失败（CI 的 pr-check
      # 就是这么挂的），同时这份拷贝还会经 bundlerEnv/gemfile-and-lockfile 进入 neovim
      # 包装产物的构建依赖。关掉之后这条路径根本不会被求值到。
      hosts.ruby.nvim-host.enable = false;

      specs.general = with vimPlugins; [
        snacks-nvim
        mini-nvim
        nvim-treesitter.withAllGrammars
        nvim-treesitter-textobjects
        nvim-treesitter-context
        catppuccin-nvim
        nvim-lspconfig
      ];
      specs.lazy = {
        lazy = true;
        data = with vimPlugins; [
          yazi-nvim
          nvim-dap
          nvim-dap-go
          nvim-dap-ui
          nvim-nio
          windsurf-nvim
          blink-cmp
          neotest
          nvim-nio
          neotest-golang
          overseer-nvim
          flash-nvim
          neogen
          nvim-lint
          render-markdown-nvim
          noice-nvim
          lazydev-nvim
          rustaceanvim
          which-key-nvim
          grug-far-nvim
          nvim-rip-substitute
          codediff-nvim
          obsidian-nvim
        ];
      };
      info = {
        values = "for lua";
        which = "will be placed in the generated info plugin for access";
      };
      runtimePkgs = with pkgs; [
        # lsps, formatters, etc...
      ];
      settings.config_directory = ./config;

      # runShell 里的命令会被写进 wrapper 生成的 bash 脚本，位置在所有环境变量设置之后、
      # 最终 `exec nvim ...` 之前，所以可以直接改 cwd 或 exec 掉自己。
      runShell = [
        {
          name = "NVIM_PRELOGIC";
          data = ''
            # 1. NVIM 已存在说明当前在 neovim 内部（:terminal 等），交给 flatnvim 转发给父实例，
            #    而不是再嵌套启动一个 neovim。
            #    FLATNVIM_PASSTHROUGH 是 flatnvim 回头调用本脚本时设置的标记（例如
            #    `nvim --version` 这类不是在父实例里打开文件的调用），此时必须放行给真正的
            #    nvim，否则会再回到 flatnvim 形成死循环。
            if [ -n "''${NVIM:-}" ]; then
              if [ -z "''${FLATNVIM_PASSTHROUGH:-}" ]; then
                exec ${lib.getExe flatnvim} "$@"
              fi

              # 不要把这个标记泄漏给 nvim 及其子进程，否则嵌套 nvim 里再执行 nvim 时
              # 转发会被跳过。
              unset FLATNVIM_PASSTHROUGH
            fi

            # 2. `nvim <dirname>`：先 cd 进去再启动，让 neovim 以该目录为 cwd
            #    （例如 dashboard 的最近文件），而不是打开 netrw 的目录视图。
            if [ "$#" -eq 1 ] && [ -d "$1" ]; then
              cd "$1" || exit 1
              shift
            fi
          '';
        }
      ];
    };

  # 安装入口：modules/base.nix 里 `imports = with self.<class>; [ neovim ]` 引用。
  # 通用的 install 模块只为声明 `wrappers.neovim.*` 选项，真正落地靠 enable 打开。
  flake.nixosModules.neovim = { wrappers.neovim.enable = true; };
  flake.darwinModules.neovim = { wrappers.neovim.enable = true; };
  flake.sysModules.neovim = { wrappers.neovim.enable = true; };
  flake.droidModules.neovim = { wrappers.neovim.enable = true; };
}
