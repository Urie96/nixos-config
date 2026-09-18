local M = {}

---@class util.storage.Item
---@field json table
---@field path string
local Item = {}
Item.__index = Item

local data_dir = vim.fn.stdpath 'data'

---@param namespace string
---@param key string
---@return table
function Item.new(namespace, key)
  local path = vim.fs.joinpath(data_dir, namespace, key .. '.json')

  local json_string
  if vim.fn.filereadable(path) == 1 then
    json_string = table.concat(vim.fn.readfile(path), '\n')
  end
  if not json_string or json_string == '' then json_string = '{}' end

  return setmetatable({
    path = path,
    json = vim.json.decode(json_string),
  }, Item)
end

function Item:sync()
  local path = self.path
  if vim.fn.filereadable(path) == 0 then
    local parent = vim.fn.fnamemodify(path, ':h')
    if vim.fn.isdirectory(parent) == 0 then
      vim.fn.mkdir(parent, 'p')
    end
  end
  vim.fn.writefile({ vim.json.encode(self.json) }, path)
end

---@type table<string, table<string, util.storage.Item>>
local cache = {}

---@param namespace string
---@param key string
function M.get(namespace, key)
  if not cache[namespace] then cache[namespace] = {} end
  if not cache[namespace][key] then cache[namespace][key] = Item.new(namespace, key) end
  return cache[namespace][key]
end

return M
