local M = {}

---@class util.repl.Config
---@field cmd string[]
---@field format? fun(lines:string[]):string
---@field highlight? string
---@field exit_on_close? boolean

---@type table<string, util.repl.Config>
local config = {
  default = {
    cmd = { vim.o.shell },
    format = function(lines)
      table.insert(lines, '')
      return table.concat(lines, '\n')
    end,
    exit_on_close = true,
  },
  python = {
    cmd = { 'python' },
    format = function(lines)
      if #lines == 1 then return lines[1] .. '\n' end
      lines = vim.tbl_map(function(line) return line == '' and ' ' or line end, lines)
      local format = table.concat(lines, '\n')
      local submit = string.match(lines[#lines], '^%s+%S') == nil and '\n' or '\n\n'
      return format .. submit
    end,
    highlight = 'python',
  },
  ipython = {
    cmd = { 'ipython', '--no-autoindent' },
    format = function(lines)
      if #lines == 1 then return lines[1] .. '\n' end
      local format = table.concat(lines, '\x0f\x1b[B\1') -- ctrl-o, down, head
      local submit = string.match(lines[#lines], '^%s+%S') == nil and '\n' or '\n\n'
      return format .. submit
    end,
  },
  nu = {
    cmd = { 'nu' },
    format = function(lines)
      table.insert(lines, '')
      return table.concat(lines, '\r\n')
    end,
  },
  fish = {
    cmd = { 'fish' },
  },
  lua = {
    cmd = { 'lua' },
    highlight = 'lua',
  },
  yaegi = {
    cmd = { 'yaegi' },
    highlight = 'go',
  },
  bash = {
    cmd = { 'bash' },
    highlight = 'bash',
  },
  node = {
    cmd = { 'node', '--experimental-repl-await' },
    highlight = 'javascript',
    format = function(lines)
      if #lines == 1 then return lines[1] .. '\n' end
      return string.format('.editor\n%s\x04', table.concat(lines, '\n')) -- <ctrl-d>
    end,
  },
  bun = {
    cmd = { 'bun', 'repl' },
    -- highlight = 'javascript',
    format = function(lines)
      if #lines == 1 then return lines[1] .. '\n' end
      return string.format('%s\n', table.concat(lines, '\x1bn')) -- <alt-n>
    end,
    exit_on_close = false,
  },
  just_repl = {
    cmd = { 'just', 'repl' },
  },
  evcxr = {
    cmd = { 'evcxr' },
    highlight = 'rust',
  },
  nix = {
    cmd = { 'nix', 'repl' },
    highlight = 'nix',
  },
}

---@class util.repl.Repl
---@field config util.repl.Config
---@field win snacks.win
---@field job any
---@field key string
local Repl = {}
Repl.__index = Repl

local function check_bun()
  if vim.fn.executable 'bun' == 1 then
    local package_json =
      vim.fs.find('package.json', { upward = true, path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)), limit = 1 })
    local bun_lock = package_json[1] and vim.fs.dirname(package_json[1]) .. '/bun.lockb'
    if bun_lock and vim.fn.filereadable(bun_lock) == 1 then return true end
  end
  return false
end

function M.smart_new()
  local ft = vim.bo.filetype
  local key = ft
  if ft == 'python' and vim.fn.executable 'ipython' == 1 then -- HACK: prefer ipython which has extra magic
    key = 'ipython'
  elseif ft == 'go' then
    key = 'yaegi'
  elseif ft == 'sh' or ft == 'bash' then
    key = 'bash'
  elseif ft == 'javascript' then
    key = check_bun() and 'bun' or 'node'
  elseif ft == 'rust' then
    key = 'evcxr'
  end
  if not config[key] then key = 'default' end
  return M.new(0, key)
end

---@param buf integer|nil
function M.select_new(buf)
  vim.ui.select(vim.tbl_keys(config), { prompt = 'Select Repl' }, function(item)
    if item then M.new(buf, item) end
  end)
end

---@param buf integer|nil
---@param key string
---@return util.repl.Repl|nil
function M.new(buf, key)
  local self = setmetatable({}, Repl)
  self.key = key
  self.config = vim.tbl_extend('force', config.default, config[key])
  local code_bufnr = buf and buf > 0 and buf or vim.api.nvim_get_current_buf()

  local repl_cmd = self.config.cmd
  if not repl_cmd or #repl_cmd == 0 then
    vim.notify('no repl cmd for ' .. key, vim.log.levels.ERROR)
    return
  end

  self:open()

  vim.keymap.set('n', '<enter>', function() self:send { vim.api.nvim_get_current_line() } end, { buffer = code_bufnr })

  vim.keymap.set('x', '<enter>', function()
    local visual = require('util.vim').get_visual()
    if visual and visual.lines then self:send(visual.lines) end
  end, { buffer = code_bufnr })

  vim.keymap.set('t', '<esc>', '<C-\\><C-n>', { buffer = self.win.buf })

  return self
end

function Repl:open()
  self.win = Snacks.win.new { position = 'right', enter = false, bo = { filetype = 'repl_' .. self.key } }

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, { buffer = self.win.buf, command = 'startinsert' })

  if self.config.exit_on_close then
    self:on_repl_exit(function()
      if type(vim.v.event) == 'table' and vim.v.event.status ~= 0 then
        Snacks.notify.error('Terminal exited with code ' .. vim.v.event.status .. '.\nCheck for any errors.')
        return
      end
      self.win:close()
      vim.cmd.checktime()
    end)
  end

  vim.api.nvim_buf_call(self.win.buf, function() self.job = vim.fn.jobstart(self.config.cmd, { term = true }) end)
  vim.notify('Repl: ' .. table.concat(self.config.cmd, ' '))

  if self.config.highlight then require('util.vim').highlight_buffer(self.win.buf, self.config.highlight) end
end

---@param cb fun()
function Repl:on_repl_exit(cb)
  if not self.exit_cb_list then
    self.exit_cb_list = {}
    self.win:on('TermClose', function()
      for _, f in pairs(self.exit_cb_list) do
        f()
      end
    end, { buffer = self.win.buf })
  end
  table.insert(self.exit_cb_list, cb)
end

function Repl:is_valid()
  if not self.win.buf or not vim.api.nvim_buf_is_valid(self.win.buf) then return false end
  local chan_info = vim.api.nvim_get_chan_info(self.job)
  return chan_info and chan_info.buffer == self.win.buf
end

---@param lines string[]|string
function Repl:send(lines)
  if self:is_valid() then
    if type(lines) == 'string' then
      vim.api.nvim_chan_send(self.job, lines)
    else
      vim.api.nvim_chan_send(self.job, self.config.format(lines))
    end
    vim.defer_fn(function() -- scroll to bottom
      local line_count = vim.api.nvim_buf_line_count(self.win.buf)
      vim.api.nvim_win_set_cursor(self.win.win, { line_count, 0 })
    end, 100)
  end
end

return M
