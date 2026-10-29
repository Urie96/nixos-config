Config.now(function()
  ---@type table<string, vim.lsp.Config>
  local servers = {
    jinja_lsp = {},
    stylua = {},
    kulala_ls = {},
    biome = {},
    jdtls = {},
    marksman = {},
    gopls = {
      cmd = { 'gopls', '-remote=auto', '-logfile=auto' },
    },
    lua_ls = {
      settings = {
        Lua = {
          doc = { privateName = { '^_' } },
          codeLens = { enable = false },
          workspace = {
            checkThirdParty = false,
            ignoreDir = { '.vscode', '.direnv', 'node_modules', '.devenv' },
          },
        },
      },
    },
    nil_ls = {},
    ruff = {},
    basedpyright = {},
    taplo = {},
    ts_ls = {},
    typos_lsp = {
      init_options = {
        diagnosticSeverity = 'Hint',
      },
    },
    thriftls = {},
    jsonls = {},
    bashls = {},
    yamlls = {},
    just = {},
    clangd = {
      -- 不用 `cmd = function()`：0.13 起这个函数必须返回 `vim.lsp.rpc.Client`，返回参数表
      -- 会被当成 rpc 客户端用（client.lua:607 attempt to call field 'request'）。
      -- 相对路径按 clangd 的 cwd 解析，而 nvim 启动 clangd 时 cwd = root_dir（client.lua：
      -- `cwd = config.cmd_cwd or config.root_dir`），所以 build 就是工程的构建目录；
      -- 还没 build 过时这个路径无效，clangd 会自己退回默认查找，无害。
      cmd = (os.getenv 'IDF_PATH') and {
        'clangd',
        '--background-index',
        -- 和下面 arduino-language-server 是同一个坑的两半：ESP-IDF 自己的头文件在 /nix/store
        -- 里，从它们的目录向上永远找不到 compile_commands.json，clangd 只能退回裸默认
        -- （esp-clang 这个二进制的默认 target 甚至还是 riscv32），于是 nvs_flash.h -> nvs.h
        -- -> esp_attr.h 这类 #include 全部解析失败，IDF 头文件里的 hover/补全也一并作废。
        -- 强制喂一个 DB 之后，clangd 会用最近的工程条目给它们内插 flags
        -- （含 components/*/include），再配合 devshell 里 clangd wrapper 的 --query-driver，
        -- newlib/stdio.h 也能找到。
        '--compile-commands-dir=build',
      } or { 'clangd', '--background-index', '--clang-tidy' },
      root_dir = function(bufnr, on_dir)
        -- 上面那条 --compile-commands-dir 只对"会话"生效，而 clangd 判断一个文件用哪份
        -- flags 是看这个文件自己的路径。所以 store 里的 IDF 源文件还得挂到工程会话上，
        -- 否则 nvim 会为它们另起一个 root_dir = nil 的 clangd。
        -- 注意不能直接用它自己的向上查找结果：IDF 每个组件目录下都有 CMakeLists.txt，
        -- 会一路匹配到 components/<组件> 甚至 IDF 根目录，把会话挂到错误的地方。
        local name = vim.api.nvim_buf_get_name(bufnr)
        local markers = { '.clangd', 'compile_commands.json', 'compile_flags.txt', 'CMakeLists.txt', '.git' }
        local idf = os.getenv 'IDF_PATH'
        local is_idf_src = name:match '^/nix/store/' ~= nil
          or (idf ~= nil and vim.fs.normalize(name):find(vim.fs.normalize(idf), 1, true) ~= nil)
        local root
        if is_idf_src then
          root = vim.fs.root(vim.fn.getcwd(), markers)
        else
          root = vim.fs.root(bufnr, markers)
        end
        if root then on_dir(root) end
      end,
      handlers = {
        -- 强制喂 DB 后，/nix/store 里的文件（IDF 源码、工具链 sysroot、第三方库）是拿原始
        -- 编译命令解析的，而工程 .clangd 的 `CompileFlags.Remove: [-m*, -f*]` 只覆盖工程
        -- 自己的文件，于是 clangd 会为 gcc 专属的 -mdisable-hardware-atomics /
        -- -fstrict-volatile-bitfields / -fno-tree-switch-conversion 报 drv_unknown_argument，
        -- 而且挂在“你正在看的那个 store 文件”的第 1 行上（打开 stdint.h 就红 stdint.h）。
        -- 这些参数只对 gcc 驱动有意义，对分析无意义；只丢这一类码，其它诊断照常。
        ['textDocument/publishDiagnostics'] = function(err, result, ctx)
          if result and result.uri and vim.fs.normalize(vim.uri_to_fname(result.uri)):match '^/nix/store/' then
            result.diagnostics = vim.tbl_filter(
              function(d) return d.code ~= 'drv_unknown_argument' end,
              result.diagnostics or {}
            )
          end
          return vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
        end,
      },
    },
    arduino_language_server = {
      cmd = {
        'arduino-language-server',
      },
      -- 默认只挂 filetype = 'arduino'（也就是 .ino）。Arduino 库自带的 .h/.cpp
      -- 也必须交给它：只有 ALS 知道本次构建的编译数据库（它的 clangd 带
      -- --compile-commands-dir），单独的 clangd 在 /nix/store 里找不到
      -- compile_commands.json，库头文件里的 #include 全部解析失败，跳转/补全全废。
      filetypes = { 'arduino', 'c', 'cpp' },
      root_dir = function(bufnr, on_dir)
        -- 库/core 源码在 /nix/store 里（不在任何 sketch 树内），向上找不到 sketch
        -- 标记，这时才退回 cwd（在 sketch 目录里启动 nvim 时就是它）。普通 C++
        -- 项目两者都匹配不到，返回 nil，ALS 就不会挂到那些 buffer 上。
        local markers = { 'sketch.yaml', 'sketch.json', '*.ino' }
        local name = vim.api.nvim_buf_get_name(bufnr)
        local marker = vim.fs.find(markers, { upward = true, path = vim.fs.dirname(name) })[1]
        if
          not marker
          and (name:match '^/nix/store/' or name:match '/%-arduino%-data/' or name:match '/Arduino/libraries/')
        then
          marker = vim.fs.find(markers, { upward = true, path = vim.fn.getcwd() })[1]
        end
        if marker then on_dir(vim.fs.dirname(marker)) end
      end,
    },
  }

  ---@type vim.lsp.Config
  local attachCodeLens = {
    on_attach = function(client, bufnr)
      if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_codeLens, bufnr) then
        vim.lsp.codelens.enable(true, { bufnr = bufnr })
        vim.api.nvim_create_autocmd({ 'BufEnter', 'InsertLeave' }, {
          buffer = bufnr,
          callback = function() vim.lsp.codelens.enable(true, { bufnr = bufnr }) end,
        })
      end
    end,
  }

  vim.lsp.config('*', attachCodeLens)

  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end

  vim.diagnostic.config {
    underline = true,
    virtual_text = true,
    update_in_insert = false,
    severity_sort = true,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = ' ',
        [vim.diagnostic.severity.WARN] = ' ',
        [vim.diagnostic.severity.HINT] = ' ',
        [vim.diagnostic.severity.INFO] = ' ',
      },
    },
  }
end)

Config.on_filetype('lua', function()
  vim.cmd.packadd 'lazydev.nvim'

  require('lazydev').setup {
    library = {
      { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      { path = 'snacks.nvim', words = { 'Snacks' } },
    },
  }
end)

Config.on_filetype('rust', function()
  vim.g.rustaceanvim = {
    -- Plugin configuration
    tools = {},
    -- LSP configuration
    server = {
      on_attach = function(client, bufnr) vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end,
      default_settings = {
        -- rust-analyzer language server configuration
        ['rust-analyzer'] = {
          cargo = {
            allFeatures = true,
            loadOutDirsFromCheck = true,
            buildScripts = {
              enable = true,
            },
          },
          checkOnSave = {
            enable = true,
          },
          diagnostics = {
            enable = true,
          },
          procMacro = {
            enable = true,
            ignored = {
              ['async-trait'] = { 'async_trait' },
              ['napi-derive'] = { 'napi' },
              ['async-recursion'] = { 'async_recursion' },
            },
          },
          files = {
            excludeDirs = {
              '.direnv', -- IMPORTANT: https://github.com/rust-lang/rust-analyzer/issues/12613
              '.devenv',
              '.git',
              '.github',
              '.gitlab',
              'bin',
              'node_modules',
              'target',
              'venv',
              '.venv',
            },
          },
        },
      },
    },
    -- DAP configuration
    dap = {},
  }
  vim.cmd.packadd 'rustaceanvim'
end)
