Config.now_if_args(function()
  local treesitter_context = require 'treesitter-context'
  local treesitter_move = require 'nvim-treesitter-textobjects.move'
  local ts = require 'nvim-treesitter-textobjects'

  ts.setup {}
  treesitter_context.setup {
    enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
    max_lines = 3, -- How many lines the window should span. Values <= 0 mean no limit.
    mode = 'cursor', -- Line used to calculate context. Choices: 'cursor', 'topline'
  }

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    -- Check if a parser exists and load it
    if not vim.treesitter.language.add(language) then return end
    -- Enable syntax highlighting and other treesitter features
    vim.treesitter.start(buf, language)

    -- Enable treesitter based folds
    -- For more info on folds see `:help folds`
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.wo.foldmethod = 'expr'

    -- Check if treesitter indentation is available for this language, and if so enable it
    -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

    -- Enable treesitter based indentation
    if has_indent_query then vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

      treesitter_try_attach(buf, language)
    end,
  })

  vim.keymap.set(
    'n',
    'ju',
    function() treesitter_context.go_to_context(vim.v.count1) end,
    { desc = 'Open yazi at the current file' }
  )

  local moves = {
    goto_next_start = { ['lf'] = '@function.outer', ['la'] = '@parameter.inner' },
    goto_next_end = { ['lF'] = '@function.outer', ['lA'] = '@parameter.inner' },
    goto_previous_start = { ['jf'] = '@function.outer', ['ja'] = '@parameter.inner' },
    goto_previous_end = { ['jF'] = '@function.outer', ['jA'] = '@parameter.inner' },
  }
  for method, keymaps in pairs(moves) do
    for key, query in pairs(keymaps) do
      vim.keymap.set({ 'n', 'x', 'o' }, key, function() treesitter_move[method](query, 'textobjects') end)
    end
  end
end)
