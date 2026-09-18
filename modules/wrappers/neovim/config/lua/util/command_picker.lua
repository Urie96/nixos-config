local util = require 'util.vim'
local storage = require 'util.storage'

local M = {}

---@class util.command_picker.ctx
---@field visual util.visual|nil
---@field buf integer
---@field win integer

---@type {name: string,callback: fun(ctx: util.command_picker.ctx)}[]
local commands = {
  {
    name = 'Git blame this file',
    callback = function(ctx) require('util.blame').show(ctx.win, ctx.buf) end,
  },
  {
    name = 'Go add JSON tag',
    callback = function(ctx) require('util.gomodifytags').add_json(ctx) end,
  },
  {
    name = 'Go add JSON tag omit empty',
    callback = function(ctx) require('util.gomodifytags').add_json_omitempty(ctx) end,
  },
  {
    name = 'Go add GORM tag',
    callback = function(ctx) require('util.gomodifytags').add_gorm(ctx) end,
  },
  {
    name = 'Go remove tag',
    callback = function(ctx) require('util.gomodifytags').remove_tags(ctx) end,
  },
  {
    name = 'Run goimports',
    callback = function(ctx) require('util.formatter').goimports(ctx.buf) end,
  },
  {
    name = 'Run golines',
    callback = function(ctx) require('util.formatter').range_fix_golines(ctx) end,
  },
  {
    name = 'Format JSON',
    callback = function(ctx) require('util.formatter').range_format_json(ctx) end,
  },
  {
    name = 'Minify JSON',
    callback = function(ctx) require('util.formatter').range_minify_json(ctx) end,
  },
  {
    name = 'Stringify',
    callback = function(ctx) require('util.formatter').range_stringify(ctx) end,
  },
  {
    name = 'Unstringify',
    callback = function(ctx) require('util.formatter').range_unstringify(ctx) end,
  },
  {
    name = 'URL Decode',
    callback = function(ctx) require('util.formatter').url_decode(ctx) end,
  },
  {
    name = 'URL Encode',
    callback = function(ctx) require('util.formatter').url_encode(ctx) end,
  },
  {
    name = 'Open REPL',
    callback = function(ctx) require('util.repl').select_new(ctx.buf) end,
  },
  {
    name = 'Snacks picker',
    callback = function(_) Snacks.picker() end,
  },
  {
    name = 'Toggle profiler',
    callback = function(_) require('snacks.profiler').toggle() end,
  },
  {
    name = 'Run test at cursor',
    callback = function(ctx) require('util.run_test').run_cursor_test(ctx.buf) end,
  },
  {
    name = 'Toggle Debug UI',
    callback = function(_) require('dapui').toggle {} end,
  },
  {
    name = 'Scratch Buffer',
    callback = function(_) require('util.scratch').select() end,
  },
  {
    name = 'Join String Array',
    callback = function(ctx) require('util.formatter').join_string_array(ctx) end,
  },
}

local nvim_cmd = {
  'CodeCompanionActions',
  'DBUIToggle',
  'DBUIAddConnection',
}

vim.list_extend(
  commands,
  vim.tbl_map(function(cmd)
    return { name = cmd, callback = function(_) vim.cmd(cmd) end }
  end, nvim_cmd)
)

local history_storage = storage.get('command_picker', 'history')

---@return {use_at: integer}
local function get_item(name)
  local json = history_storage.json
  if not json[name] then json[name] = { use_at = 0 } end
  return json[name]
end

function M.pick()
  ---@type util.command_picker.ctx
  local ctx = {
    visual = util.get_visual(),
    buf = vim.api.nvim_get_current_buf(),
    win = vim.api.nvim_get_current_win(),
  }
  table.sort(commands, function(a, b) return get_item(a.name).use_at > get_item(b.name).use_at end)
  vim.ui.select(commands, { prompt = 'Actions', format_item = function(item) return item.name end }, function(item)
    if not item then return end
    item.callback(ctx)
    get_item(item.name).use_at = os.time()
    history_storage:sync()
  end)
end

return M
