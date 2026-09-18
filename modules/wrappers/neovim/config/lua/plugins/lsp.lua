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
      cmd = (function()
        local cmd = {
          'arduino-language-server',
        }
        if vim.env.ARDUINO_CLI_CONFIG then
          table.insert(cmd, '--cli-config')
          table.insert(cmd, vim.env.ARDUINO_CLI_CONFIG)
        end
        return cmd
      end)(),
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
