local storage = require 'util.storage'

local M = {}

local function get_storage()
  local cwd = vim.uv.cwd()
  assert(cwd)
  local key = vim.fn.sha256(cwd)
  return storage.get('marker', key)
end

function M.list() return get_storage().json end

function M.sync() get_storage():sync() end

local function get_current_branch()
  local current_branch_proc = vim.system({ 'git', 'rev-parse', '--abbrev-ref', 'HEAD' }, { text = true }):wait()
  return current_branch_proc.code == 0 and current_branch_proc.stdout or nil
end

function M.add()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]
  local file = vim.api.nvim_buf_get_name(0)
  local now = os.time()
  local list = M.list()
  table.insert(list, 1, {
    file = file,
    row = row,
    col = col,
    id = now,
    created_at = now,
    view_at = now,
    branch = get_current_branch(),
  })
  vim.notify(string.format('Added mark of %s at row %d', file, row))
  M.sync()
end

function M.delete(id)
  local list = M.list()
  for i, item in ipairs(list) do
    if item.id == id then
      table.remove(list, i)
      M.sync()
      return item
    end
  end
end

function M.touch(id)
  local list = M.list()
  for _, item in ipairs(list) do
    if item.id == id then
      item.view_at = os.time()
      M.sync()
      return
    end
  end
end

function M.pick()
  local current_branch = get_current_branch()

  local function finder(opts, ctx)
    local res = vim.tbl_map(function(i)
      local score = i.view_at
      if i.branch == current_branch then score = score * 10 end
      ---@type snacks.picker.finder.Item
      return {
        text = i.file,
        file = i.file,
        pos = { i.row, i.col },
        created_at = i.created_at,
        branch = i.branch,
        mark_id = i.id,
        _score = score,
      }
    end, M.list())
    table.sort(res, function(a, b) return a._score > b._score end)
    return res
  end

  local function formatter(item, picker)
    local base = require('snacks.picker.format').file(item, picker)
    local a = Snacks.picker.util.align
    local desc = Util.relative_date_desc(item.created_at)
    local branch_format = item.branch == current_branch and '*' or item.branch
    return vim.list_extend({
      { a(desc, 10), 'Directory' },
      { a(branch_format, 15), 'Constant' },
    }, base)
  end

  local function action_delete_mark(picker)
    local items = picker:selected { fallback = true }
    if #items == 0 then return end
    for _, item in ipairs(items) do
      M.delete(item.mark_id)
    end
    picker.list:set_selected()
    picker.list:set_target()
    picker:find()
  end

  local function action_confirm(picker, item, action)
    if item then M.touch(item.mark_id) end
    return require('snacks.picker.actions').jump(picker, item, action)
  end

  Snacks.picker {
    finder = finder,
    format = formatter,
    actions = { delete = action_delete_mark },
    confirm = action_confirm,
  }
end

return M
