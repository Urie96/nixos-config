local au = vim.api.nvim_create_autocmd
local function ag(name) return vim.api.nvim_create_augroup('my_' .. name, { clear = true }) end

-- close some filetypes with <q>
au('FileType', {
  group = ag 'close_with_q',
  pattern = {
    'sqls_output',
    'PlenaryTestPopup',
    'checkhealth',
    'dbout',
    'gitsigns-blame',
    'grug-far',
    'help',
    'lspinfo',
    'neotest-output',
    'neotest-output-panel',
    'neotest-summary',
    '*.kulala_ui',
    'notify',
    'qf',
    'spectre_panel',
    'startuptime',
    'tsplayground',
    'snacks_picker_input',
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.b[event.buf].completion = false
    vim.schedule(function()
      vim.keymap.set('n', 'q', function()
        vim.cmd 'close'
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, {
        buffer = event.buf,
        silent = true,
        desc = 'Quit buffer',
      })
    end)
  end,
})

local write_osc52_on_yank
if vim.env.SSH_TTY then write_osc52_on_yank = require('vim.ui.clipboard.osc52').copy '+' end

au('TextYankPost', {
  group = ag 'highlight-yank',
  callback = function()
    vim.hl.hl_op()
    if write_osc52_on_yank then write_osc52_on_yank(vim.v.event.regcontents) end
  end,
})

au('FileType', {
  group = ag 'disable_spell',
  pattern = 'markdown',
  callback = function() vim.opt_local.spell = false end,
})

local jupytext = ag 'jupytext'
au('BufReadCmd', {
  pattern = { '*.ipynb' },
  group = jupytext,
  callback = function(ev) require('util.jupytext').read_from_ipynb(ev.buf) end,
})
au({ 'BufWriteCmd', 'FileWriteCmd' }, {
  pattern = { '*.ipynb' },
  group = jupytext,
  callback = function(ev) require('util.jupytext').write_to_ipynb(ev.buf) end,
})

-- go to last loc when opening a buffer
au('BufReadPost', {
  group = ag 'last_loc',
  callback = function(event)
    local exclude = { 'gitcommit' }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then return end
    vim.b[buf].lazyvim_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
  end,
})

au({ 'BufWritePre' }, {
  desc = 'Format on save',
  pattern = '*',
  group = ag 'format_on_save',
  callback = function(args) require('util.formatter').format_buf(args.buf, { code_action = true }) end,
})
