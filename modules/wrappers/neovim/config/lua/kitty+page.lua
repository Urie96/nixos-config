vim.loader.enable()
vim.env.PATH = vim.env.HOME .. '/bin:/run/current-system/sw/bin:' .. vim.env.PATH -- translate
require 'plugins.global_var'

--- Lazy-load snacks.nvim on field access
_G.Snacks = setmetatable({}, {
  __index = function(_, k)
    local snacks = require 'snacks'
    return snacks[k]
  end,
  __newindex = function() end,
})

local M = {}

local INPUT_LINE_NUMBER, CURSOR_LINE, CURSOR_COLUMN = nil, 0, 0

Config.on_keys({ 's' }, { 'n', 'x', 'o' }, function()
  vim.cmd.packadd 'flash.nvim'

  require('flash').setup {
    modes = {
      char = {
        highlight = { backdrop = false },
        multi_line = false,
      },
    },
  }
  vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end)
  vim.api.nvim_set_hl(0, 'Substitute', { bg = '#ff757f', fg = '#1b1d2b' })
end)

Config.on_keys({ 'v' }, function() require('mini.ai').setup { search_method = 'cover' } end)

function M.set_keymap(buf)
  require 'config.keymaps'
  vim.keymap.set('n', 'q', '<Cmd>qa!<CR>', { buf = buf })
  vim.keymap.set('n', '<C-q>', '<Cmd>qa!<CR>', { buf = buf })
end

function M.set_options()
  vim.opt.encoding = 'utf-8'
  -- Prevent auto-centering on click
  vim.opt.scrolloff = 0
  vim.opt.compatible = false
  vim.opt.number = false
  vim.opt.relativenumber = false
  vim.opt.termguicolors = true
  vim.opt.showmode = false
  vim.opt.ruler = false
  vim.opt.signcolumn = 'no'
  vim.opt.showtabline = 0
  vim.opt.laststatus = 0
  vim.o.cmdheight = 0
  vim.o.ignorecase = true
  vim.opt.showcmd = false
  vim.opt.scrollback = 100000
  vim.opt.clipboard:append 'unnamedplus'
end

---@param num number
---@param min number
---@param max number
---@return number
local function bounded_number(num, min, max)
  if num < min then return min end
  if num > max then return max end
  return num
end

local function remove_trailing()
  vim.opt_local.modifiable = true
  vim.cmd [[%s/\s\+$//e]]
  vim.opt_local.modifiable = false
end

function M.set_autocmd(term_buf)
  require 'config.autocmds'

  local set_cursor = function()
    local max_line_nr = vim.api.nvim_buf_line_count(term_buf)
    local input_line_nr
    local cursor_line_nr
    local cursor_column = CURSOR_COLUMN

    if INPUT_LINE_NUMBER == nil then
      input_line_nr = bounded_number(max_line_nr - vim.api.nvim_win_get_height(0), 1, max_line_nr)
      cursor_line_nr = max_line_nr
      local last_line = vim.api.nvim_buf_get_lines(term_buf, -2, -1, false)[1] or ''
      cursor_column = #last_line
    else
      input_line_nr = bounded_number(INPUT_LINE_NUMBER > 0 and INPUT_LINE_NUMBER or max_line_nr, 1, max_line_nr)
      cursor_line_nr = bounded_number(CURSOR_LINE + input_line_nr, 1, max_line_nr)
    end

    vim.fn.winrestview { topline = input_line_nr }
    vim.api.nvim_win_set_cursor(0, { cursor_line_nr, cursor_column })
  end

  local group = vim.api.nvim_create_augroup('kitty+page', { clear = true })
  vim.api.nvim_create_autocmd('ModeChanged', {
    group = group,
    buffer = term_buf,
    callback = function()
      local mode = vim.fn.mode()
      if mode == 't' then
        vim.cmd.stopinsert()
        vim.schedule(set_cursor)
      end
    end,
  })

  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    once = true,
    pattern = '*',
    callback = function()
      -- Use vim.defer_fn to make sure the terminal has time to process the content and the buffer is ready.

      vim.defer_fn(function()
        set_cursor()
        vim.defer_fn(function() -- 不然会蓝屏
          remove_trailing()
          set_cursor()
        end, 10)
      end, 10)
    end,
  })
end

function M.set_term_buf()
  local term_buf = vim.api.nvim_create_buf(true, false)
  local term_io = vim.api.nvim_open_term(term_buf, {})
  local group = vim.api.nvim_create_augroup('kitty+page_set_term_buf', { clear = true })

  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    once = true,
    pattern = '*',
    callback = function(ev)
      local current_win = vim.fn.win_getid()
      -- Instead of sending lines individually, concatenate them.
      local main_lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -2, false)
      local content = table.concat(main_lines, '\r\n')
      vim.api.nvim_chan_send(term_io, content .. '\r\n')

      -- Process the last line separately (without trailing \r\n)
      local last_line = vim.api.nvim_buf_get_lines(ev.buf, -2, -1, false)[1]
      if last_line then vim.api.nvim_chan_send(term_io, last_line) end
      vim.api.nvim_win_set_buf(current_win, term_buf)
      vim.api.nvim_buf_delete(ev.buf, { force = true })
    end,
  })

  return term_buf
end

function M.set_color()
  local color = {
    Substitute = { bg = '#f7768e', fg = '#15161e' },
    Comment = { fg = '#565f89', italic = true },
    Search = { bg = '#3d59a1', fg = '#c0caf5' },
    IncSearch = { bg = '#ff9e64', fg = '#15161e' },
    MsgArea = { fg = '#a9b1d6' },
    Normal = { bg = '#2a2a2a', fg = '#cdd6f4' },
  }
  for k, v in pairs(color) do
    vim.api.nvim_set_hl(0, k, v)
  end
end

---@param input_line_number? string
---@param cursor_line? string
---@param cursor_column? string
function M.entry(input_line_number, cursor_line, cursor_column)
  INPUT_LINE_NUMBER = tonumber(input_line_number)
  CURSOR_LINE = tonumber(cursor_line) or 0
  CURSOR_COLUMN = tonumber(cursor_column) or 0

  local term_buf = M.set_term_buf()

  M.set_color()
  M.set_keymap(term_buf)
  M.set_options()
  M.set_autocmd(term_buf)
end

return M
