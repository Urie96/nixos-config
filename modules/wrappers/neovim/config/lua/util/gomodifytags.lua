local util = require 'util.vim'

local M = {}

---@param ctx util.command_picker.ctx
---@param args string[]
local function exec_add_go_tag(ctx, args)
  local bufname = vim.api.nvim_buf_get_name(ctx.buf)
  local cmd = {
    'gomodifytags',
    '-w',
    '-file',
    bufname,
  }

  if not ctx.visual then
    local pos = vim.api.nvim_win_get_cursor(ctx.win)
    vim.list_extend(cmd, { '-offset', vim.api.nvim_buf_get_offset(ctx.buf, pos[1]) })
  else
    local start_line = ctx.visual.pos[1]
    local end_line = ctx.visual.end_pos[1]
    vim.list_extend(cmd, { '-line', start_line .. ',' .. end_line })
  end

  vim.list_extend(cmd, args)

  vim.cmd 'noa w' -- write when the buffer has been modified
  -- vim.fn.execute(":update")
  local output = vim.fn.system(cmd)
  if vim.api.nvim_get_vvar 'shell_error' == 0 then
    vim.fn.execute(':e ' .. bufname) -- reload the file
  else
    vim.notify(output, vim.log.levels.ERROR)
  end
end

---@param ctx util.command_picker.ctx
function M.add_json(ctx)
  local args = { '--add-tags', 'json' }
  exec_add_go_tag(ctx, args)
end

---@param ctx util.command_picker.ctx
function M.add_json_omitempty(ctx)
  local args = { '--add-tags', 'json', '-add-options', 'json=omitempty' }
  exec_add_go_tag(ctx, args)
end

---@param ctx util.command_picker.ctx
function M.add_gorm(ctx)
  local args = { '-add-tags', 'gorm', '-template', 'column:{field}' }
  exec_add_go_tag(ctx, args)
end

---@param ctx util.command_picker.ctx
function M.remove_tags(ctx)
  local args = { '-clear-tags' }
  exec_add_go_tag(ctx, args)
end

return M
