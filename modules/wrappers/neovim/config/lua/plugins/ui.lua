---@diagnostic disable: missing-fields

Config.now(function()
  require('catppuccin').setup {
    flavour = 'macchiato',
    kitty = false, -- 禁止颜色偏移
  }
  vim.cmd.colorscheme 'catppuccin-nvim'
end)

Config.now(function()
  require('mini.statusline').setup()
  -- Override: always show relative path instead of absolute
  MiniStatusline.section_filename = function(args)
    if vim.bo.buftype == 'terminal' then return '%t' end
    local rel = vim.fn.fnamemodify(vim.fn.expand '%', ':.')
    if rel == '' then rel = vim.fn.expand '%:t' end
    return rel .. '%m%r'
  end
end)

-- Config.later(function()
--   vim.pack.add { 'https://github.com/nvim-lualine/lualine.nvim' }
--
--   local lualine = require 'lualine'
--
--   local rec_msg = '' -- TODO: wait PR merged: https://github.com/nvim-lualine/lualine.nvim/pull/1227
--   vim.api.nvim_create_autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
--     group = vim.api.nvim_create_augroup('LualineRecordingSection', { clear = true }),
--     callback = function(e)
--       if e.event == 'RecordingLeave' then
--         rec_msg = ''
--       else
--         rec_msg = 'Recording @' .. vim.fn.reg_recording()
--       end
--       lualine.refresh()
--     end,
--   })
--
--   lualine.setup {
--     sections = {
--       lualine_c = {
--         { 'filename', path = 1 },
--         {
--           function() return rec_msg end,
--           color = { fg = '#ff9e64' },
--         },
--       },
--     },
--   }
-- end)

Config.on_filetype('markdown', function()
  vim.cmd.packadd 'render-markdown.nvim'
  require('render-markdown').setup {}
end)

Config.later(function()
  -- vim.pack.add { 'https://github.com/folke/noice.nvim', 'https://github.com/MunifTanjim/nui.nvim' }
  vim.cmd.packadd 'noice.nvim'
  require('noice').setup {}
  vim.keymap.set('n', '<PageDown>', function()
    if not require('noice.lsp').scroll(6) then return '<c-d>' end
  end, { silent = true, expr = true, desc = 'Scroll Forward' })
  vim.keymap.set('n', '<PageUp>', function()
    if not require('noice.lsp').scroll(-6) then return '<c-u>' end
  end, { silent = true, expr = true, desc = 'Scroll Backward' })
end)
