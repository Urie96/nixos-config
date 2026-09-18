local map = Config.set_keymap

Config.on_cmd({ 'WhichKey' }, function()
  vim.cmd.packadd 'which-key.nvim'
  require('which-key').setup {}
end)

Config.on_keys({ '<leader>sr' }, function()
  vim.cmd.packadd 'grug-far.nvim'

  local grug = require 'grug-far'
  grug.setup {
    minSearchChars = 1,
    normalModeSearch = true,
    resultsHighlight = false,
    inputsHighlight = false,
    keymaps = {
      help = { n = '?' },
      historyOpen = { n = '<c-o>' },
    },
    resultLocation = {
      showNumberLabel = false,
    },
  }

  map {
    '<leader>sr',
    function()
      local ext = vim.bo.buftype == '' and vim.fn.expand '%:e'
      grug.open {
        transient = true,
        prefills = {
          filesFilter = ext and ext ~= '' and '*.' .. ext or nil,
          paths = vim.fn.expand '%',
        },
      }
    end,
    desc = 'Search and Replace',
  }
end)

Config.on_keys({ '<leader>sr' }, { 'x' }, function()
  vim.cmd.packadd 'nvim-rip-substitute'
  local rip = require 'rip-substitute'
  map { '<leader>sr', function() rip.sub() end, mode = { 'x' }, desc = ' rip substitute' }
end)

local setup_codediff = Config.once(function()
  vim.cmd.packadd 'codediff.nvim'
  require('codediff').setup {
    diff = {
      ignore_trim_whitespace = true, -- Ignore leading/trailing whitespace changes (like diffopt+=iwhite)
      cycle_next_hunk = false, -- Wrap around when navigating hunks (]c/[c): false to stop at first/last
      cycle_next_file = false, -- Wrap around when navigating files (]f/[f): false to stop at first/last
      compact_context_lines = 10, -- Number of context lines around hunks in compact mode
    },
    explorer = {
      view_mode = 'tree',
    },
    keymaps = {
      view = {
        next_file = 'lf', -- Next file in explorer/history mode
        prev_file = 'jf', -- Previous file in explorer/history mode
      },
    },
  }
  vim.keymap.set('n', '<leader>cr', '<cmd>CodeDiff origin/HEAD<cr>', { desc = 'Code review' })
end)

Config.on_keys({ '<leader>cr' }, setup_codediff)
Config.on_cmd({ 'CodeDiff' }, setup_codediff)

-- local setup_rime = Config.once(function()
--   vim.pack.add { 'https://github.com/Urie96/rime.nvim' }
--   local rime = require 'rime'
--   rime.setup {} -- 按上下文自动切换中/英文输入已内置在插件 setup 中
--
--   vim.keymap.set('i', '<C-space>', function() rime.toggle() end, { desc = 'Toggle Rime' })
-- end)
-- Config.on_keys({ '<C-space>' }, 'i', setup_rime)
-- Config.on_filetype('markdown', setup_rime)

local setup_obsidian = Config.once(function()
  vim.cmd.packadd 'obsidian.nvim'
  require('obsidian').setup {
    legacy_commands = false, -- this will be removed in 4.0.0
    picker = {
      name = 'snacks.picker',
    },
    workspaces = {
      {
        name = 'personal',
        path = '~/Documents/obsidian',
      },
    },
  }
end)

Config.on_cmd({ 'Obsidian' }, setup_obsidian)
