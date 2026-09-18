Config.now(function()
  require('mini.icons').setup {
    use_file_extension = function(ext, _)
      local suf3, suf4 = ext:sub(-3), ext:sub(-4)
      return suf3 ~= 'scm' and suf3 ~= 'txt' and suf3 ~= 'yml' and suf4 ~= 'json' and suf4 ~= 'yaml'
    end,
  }
  Config.later(MiniIcons.mock_nvim_web_devicons)
  Config.later(MiniIcons.tweak_lsp_kind)
end)

Config.now(function() require('mini.tabline').setup() end)

Config.later(function()
  local ai = require 'mini.ai'
  ai.setup {
    n_lines = 500,
    search_method = 'cover',
    custom_textobjects = {
      o = ai.gen_spec.treesitter { -- code block
        a = { '@block.outer', '@conditional.outer', '@loop.outer' },
        i = { '@block.inner', '@conditional.inner', '@loop.inner' },
      },
      f = ai.gen_spec.treesitter { a = '@function.outer', i = '@function.inner' }, -- function
      c = ai.gen_spec.treesitter { a = '@class.outer', i = '@class.inner' }, -- class
      u = ai.gen_spec.function_call(), -- u for "Usage"
    },
    mappings = {
      goto_left = 'jj',
      goto_right = 'll',
    },
  }
end)

Config.on_keys({ '()', '[]', '{}', '"', "'" }, { 'x' }, function()
  require('mini.surround').setup {
    custom_surroundings = {
      -- default insert spaces, custom to remove spaces
      ['('] = { output = { left = '(', right = ')' } },
      ['['] = { output = { left = '[', right = ']' } },
      ['{'] = { output = { left = '{', right = '}' } },
    },
    mappings = {
      add = 'gza', -- Add surrounding in Normal and Visual modes
    },
  }
  vim.keymap.set('x', '()', 'gza(', { remap = true })
  vim.keymap.set('x', '[]', 'gza[', { remap = true })
  vim.keymap.set('x', '{}', 'gza{', { remap = true })
  vim.keymap.set('x', '"', 'gza"', { remap = true })
  vim.keymap.set('x', "'", "gza'", { remap = true })
end)

Config.on_keys({ 'gs' }, function() require('mini.splitjoin').setup { mappings = { toggle = 'gs' } } end)

Config.on_keys({ 'ga' }, { 'x' }, function() require('mini.align').setup() end)

Config.on_event('InsertEnter', function()
  require('mini.pairs').setup {
    mappings = {
      ['('] = { action = 'open', pair = '()', neigh_pattern = '[^\\].', register = { bs = false } },
      ['['] = { action = 'open', pair = '[]', neigh_pattern = '[^\\].', register = { bs = false } },
      ['{'] = { action = 'open', pair = '{}', neigh_pattern = '[^\\].', register = { bs = false } },

      -- [')'] = { action = 'close', pair = '()', neigh_pattern = '[^\\].', register = { bs = false } },
      -- [']'] = { action = 'close', pair = '[]', neigh_pattern = '[^\\].', register = { bs = false } },
      -- ['}'] = { action = 'close', pair = '{}', neigh_pattern = '[^\\].', register = { bs = false } },

      ['"'] = { action = 'closeopen', pair = '""', neigh_pattern = '[^\\].', register = { cr = false, bs = false } },
      ["'"] = {
        action = 'closeopen',
        pair = "''",
        neigh_pattern = '[^%a\\].',
        register = { cr = false, bs = false },
      },
      ['`'] = { action = 'closeopen', pair = '``', neigh_pattern = '[^\\].', register = { cr = false, bs = false } },
    },
  }
end)

Config.later(function()
  local diff = require 'mini.diff'
  diff.setup {
    view = {
      style = 'sign',
      signs = {
        add = '▎',
        change = '▎',
        delete = '',
      },
    },
  }

  vim.keymap.set('n', '<leader>go', function() diff.toggle_overlay(0) end, { desc = 'Toggle mini.diff overlay' })
end)
