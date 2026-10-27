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
      cmd = (os.getenv 'IDF_PATH') and { 'clangd', '--background-index', '--query-driver=**' }
        or { 'clangd', '--background-index', '--clang-tidy' },
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
