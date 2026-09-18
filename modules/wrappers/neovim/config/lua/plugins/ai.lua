local start_pos = string.find(vim.uv.cwd() or '', '/work/')
local use_work_ai = start_pos ~= nil and os.getenv 'WORK'

if not use_work_ai then
  Config.on_event('InsertEnter', function()
    vim.cmd.packadd 'windsurf.nvim'

    local windsurf = require 'codeium'
    local windsurf_config = require 'codeium.config'
    local allow_ft =
      vim.split('sh,go,rust,python,lua,nix,java,c,cpp,javascript,typescript,json,yaml,toml,sql,html,css,markdown', ',')
    local ft_table = {}
    for _, ft in ipairs(allow_ft) do
      ft_table[ft] = true
    end

    Snacks.toggle({
      name = 'AI',
      get = function() return windsurf_config.options.virtual_text.manual ~= true end,
      set = function(state)
        if state then
          windsurf_config.options.virtual_text.manual = false
        else
          windsurf_config.options.virtual_text.manual = true
        end
      end,
    }):map '<leader>uA'

    windsurf.setup {
      enable_cmp_source = false,
      virtual_text = {
        enabled = true,
        filetypes = ft_table,
        default_filetype_enabled = false,
        key_bindings = {
          accept = '<C-l>',
        },
      },
    }
    -- 让插件在懒加载完成后正确初始化 virtual text 高亮（CodeiumSuggestion），
    -- 否则高亮组未定义，回退到 Normal.fg = 白色，与已输入代码无法区分。
    vim.schedule(function() vim.cmd.colorscheme 'catppuccin-nvim' end)
  end)
else
  Config.on_event('InsertEnter', function()
    vim.g.marscode_no_map_tab = true
    vim.g.marscode_disable_bindings = true

    vim.pack.add { 'https://code.byted.org/chenjiaqi.cposture/codeverse.vim.git' }

    vim.cmd 'inoremap <script><silent><nowait><expr> <C-Tab> trae#Accept()'
    vim.cmd 'imap <C-Enter> <Plug>(marscode-next-or-complete)'

    -- 同上：vim.schedule 确保插件初始化完成后触发 ColorScheme 事件，
    -- 让插件有机会定义 virtual text 高亮组，避免白色无法区分。
    vim.schedule(function() vim.cmd.colorscheme 'catppuccin-nvim' end)
  end)
end
