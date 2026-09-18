---@diagnostic disable: missing-fields

-- https://neovim.io/doc/user/lua.html#map()
-- echo keyname: first press ctrl+v in insert mode, then press your key
local n, i, x, c, t = 'n', 'i', 'x', 'c', 't'
local map = Config.set_keymap

local unmap = function(arg)
  if type(arg) == 'string' then vim.keymap.del(n, arg) end
  local mode = arg.mode or n
  for _, lhs in ipairs(arg) do
    vim.keymap.del(mode, lhs)
  end
end
unmap { 'grr', 'gri', 'gra', 'grn', 'grt' }
unmap { '<tab>', mode = i } -- remove smart tab: https://github.com/neovim/neovim/commit/123f8d229eef05869ee4c98dfd4934c22a03b1f6

map { 'j', '[', remap = true }
map { 'l', ']', remap = true }
map {
  '<Esc>',
  '<Cmd>nohlsearch|diffupdate|call nvim_buf_clear_namespace(0, nvim_create_namespace("nvim.multicursor"), 0, -1)<CR>',
  desc = 'Clear Highlights On Search',
}
map { '<Down>', 'gj', mode = { n, x }, desc = 'Down' } -- adapt wrap line
map { '<Up>', 'gk', mode = { n, x }, desc = 'Up' } -- adapt wrap line

map { '<PageDown>', '<C-d>' }
map { '<PageUp>', '<C-u>' }

-- copy to clipboard ( use osc52 if ssh )
map { '<leader>yy', '"+y', mode = { x, n }, desc = 'Copy Using OSC52' }

map { '<C-p>', '"0p', mode = { x, n } }
map { '<C-p>', '<c-r>0', mode = i }
map { 'Y', '^y$', desc = 'Copy Line Without Newline' }
-- map('<C-l>', '<cmd>bnext<cr>', 'Switch to Right Buffer')
-- map('<C-j>', '<cmd>bprevious<cr>', 'Switch to Left Buffer')
map { 'g:', 'g;', mode = { n, x }, desc = 'Jump older change list' }
map { '<M-BS>', '<C-w>', mode = { i, c }, desc = 'Delete Word' }
map { '<M-Left>', '<C-Left>', mode = i, desc = 'Jump Backward Word' }
map { '<M-Right>', '<C-Right>', mode = i, desc = 'Jump Forward Word' }

map { '<C-s>', '<cmd>w!<cr>', mode = { n, i }, desc = 'Save File' }

map { '<leader>qa', '<cmd>qa<cr>', desc = 'Quit All' }
map { '<C-S-s>', '<cmd>noa w<cr><esc>', mode = { n, i }, desc = 'Save Without Format' }
map {
  '<leader>fm',
  function() require('util.formatter').format_buf(0, { async = true }) end,
  desc = 'Format',
}
map { '<C-a>', 'ggVG', desc = 'Select All' }
map { '<Home>', '^', mode = { n, x }, desc = 'Jump to Line First Char' }
map { '<Home>', '<C-o>I', mode = i, desc = 'Jump to Line First Char' }
-- windows
map { '<C-w>j', '<cmd>wincmd h<cr>', desc = 'Focus Left Window' }
map { '<C-w>i', '<cmd>wincmd k<cr>', desc = 'Focus Above Window' }
map { '<C-w>k', '<cmd>wincmd j<cr>', desc = 'Focus Below Window' }
local function cycle_window()
  vim.cmd 'wincmd w'
  if vim.tbl_contains({ 'snacks_notif' }, vim.bo.filetype) then cycle_window() end
end
map { '<C-k>', cycle_window, mode = { n, t }, desc = 'Cycle Windows' }
map {
  '<C-w>n',
  function() vim.api.nvim_open_win(0, false, { split = 'right', win = 0 }) end,
  desc = 'New Window',
}
map {
  '<C-w>o',
  function()
    vim.cmd 'wincmd t'
    local this_window = vim.api.nvim_win_get_config(0)
    if this_window.split == 'left' or this_window.split == 'right' then
      vim.cmd 'wincmd K'
    else
      vim.cmd 'wincmd H'
    end
  end,
  desc = 'Rotato Window',
}
-- buffers
map { '<leader>bn', function() require('util.scratch').select() end, desc = 'Scratch Buffer' }
map { '<C-j>', '<cmd>bp<cr>' }
map { '<C-l>', '<cmd>bn<cr>' }
-- tabs
map { '<leader><tab>n', '<cmd>tab split<cr>', desc = 'New Tab' }
map { '<leader><tab><tab>', '<cmd>tabnext<cr>', desc = 'Next Tab' }
map { '<leader><tab>q', '<cmd>tabclose<cr>', desc = 'Close Tab' }

map { '<leader>gg', function() require('util.git_files').pick() end, desc = 'My Git Files' }
map { 'ma', function() require('util.marker').add() end, desc = 'Add Marker' }
map { 'mm', function() require('util.marker').pick() end, desc = 'List Markers' }
map { '<leader>rr', vim.lsp.buf.rename, desc = 'Rename Symbol' }
map { '<leader>ca', vim.lsp.buf.code_action, desc = 'Code Action' }
map { '<leader>cc', vim.lsp.codelens.run, desc = 'Run Codelens' }
map {
  '<leader>co',
  function() vim.lsp.buf.code_action { context = { only = { 'source.organizeImports' } }, apply = true } end,
  desc = 'Organize Imports',
}
map {
  '<leader><cr>',
  function() require('util.run_file').run_file() end,
  desc = 'Run File',
}

-- Add undo break-points
map { '<space>', '<space><c-g>u', mode = i }
map { ',', ',<c-g>u', mode = i }
map { '.', '.<c-g>u', mode = i }
map { ';', ';<c-g>u', mode = i }

-- better indenting
map { '<', '<gv', mode = x }
map { '>', '>gv', mode = x }

-- marks
-- auto increase mark
-- local mark_index = 0
-- map('n', 'mA', function()
--   if mark_index == 0 then
--     vim.cmd 'delmarks A-Z0-9'
--     -- vim.cmd("delmarks!")
--   end
--   local mark = string.char(65 + mark_index % 26)
--   vim.cmd.normal('m' .. mark)
--   mark_index = mark_index + 1
-- end)

map {
  'yp',
  function()
    local path = vim.fn.expand '%:~:.' .. ':' .. vim.fn.line '.'
    vim.fn.setreg('+', path)
    vim.notify('Copied: ' .. path)
  end,
  desc = 'Copy CurrentFile:LineNumber',
}

-- comment like vs code
map { '<D-/>', 'gcc', remap = true }
map { '<D-/>', '<C-o>gcc', mode = i, remap = true }
map { '<D-/>', 'gc', mode = x, remap = true }
map { '<C-Space>', function() end, mode = i } -- disable this keymap as it's for toggle system input method

local function translate(text)
  local cmd = { 'translate', '--ai' }
  vim.system(cmd, { stdin = text }, function(out)
    local tips = out.stdout
    if out.code > 0 then
      tips = string.format('`%s` exited with code %d, stderr: %s', table.concat(cmd, ' '), out.code, out.stderr)
    end
    (require 'util.vim').show_tip(tips)
  end)
end

map {
  'K',
  function()
    local current_word = vim.fn.expand '<cword>'
    if current_word:match '^%d+$' and (#current_word == 10 or #current_word == 13) then
      local timestamp = tonumber(current_word) or 0
      if #current_word == 13 then timestamp = timestamp / 1000 end
      local time_format = require('util.formatter').format_timestamp(timestamp)
      require('util.ui').show_temporary_popup(time_format)
    elseif vim.startswith(vim.fn.expand '<cfile>', 'http') then
      require('util.image').show_hover_image()
    elseif require('util.treesitter').cursor_in_capture 'comment' then
      local comment = (require 'util.treesitter').get_comment_block()
      if comment then translate(comment) end
    else
      vim.lsp.buf.hover()
    end
  end,
  desc = 'Smart Hover',
}
map {
  'v',
  function()
    if vim.treesitter.get_parser(nil, nil, { error = false }) then
      require('vim.treesitter._select').select_parent(vim.v.count1)
    else
      vim.lsp.buf.selection_range(vim.v.count1)
    end
  end,
  mode = x,
  desc = 'Select parent (outer) node',
}
map {
  '<bs>',
  function()
    if vim.treesitter.get_parser(nil, nil, { error = false }) then
      require('vim.treesitter._select').select_child(vim.v.count1)
    else
      vim.lsp.buf.selection_range(-vim.v.count1)
    end
  end,
  mode = { x, o },
  desc = 'Select child (inner) node',
}

-- map { '<C-k><C-k>', vim.lsp.buf.signature_help, mode = i, desc = 'Signature Help' }
map {
  'K',
  function()
    local util = require 'util.vim'
    local visual = util.get_visual()
    if visual then translate(visual.lines) end
  end,
  mode = x,
  desc = 'Translate',
}

-- quickfix list
map { 'jq', vim.cmd.cprev, desc = 'Previous Quickfix' }
map { 'lq', vim.cmd.cnext, desc = 'Next Quickfix' }

-- diagnostic
local diagnostic_goto = function(next, severity)
  local count = next and 1 or -1
  severity = severity and vim.diagnostic.severity[severity] or nil
  return function() vim.diagnostic.jump { count = count, severity = severity } end
end
map { '<leader>q', vim.diagnostic.setloclist, desc = 'Open diagnostic [Q]uickfix list' }
map { '<leader>cd', vim.diagnostic.open_float, desc = 'Line Diagnostics' }
map { 'ld', diagnostic_goto(true), desc = 'Next Diagnostic' }
map { 'jd', diagnostic_goto(false), desc = 'Prev Diagnostic' }
map { 'le', diagnostic_goto(true, 'ERROR'), desc = 'Next Error' }
map { 'je', diagnostic_goto(false, 'ERROR'), desc = 'Prev Error' }
map { 'lw', diagnostic_goto(true, 'WARN'), desc = 'Next Warn' }
map { 'jw', diagnostic_goto(false, 'WARN'), desc = 'Prev Warn' }

map { '<leader>lz', '<cmd>Lazy<cr>', desc = 'Lazy' }

map {
  '<leader>rp',
  function() require('util.repl').smart_new() end,
  desc = 'New Repl',
}

map {
  '<leader>cp',
  function() require('util.command_picker').pick() end,
  desc = 'My Command Picker',
  mode = { n, x },
}

map {
  'jjf',
  function() require('util.treesitter').jump_function_name() end,
  mode = { n, x },
}
