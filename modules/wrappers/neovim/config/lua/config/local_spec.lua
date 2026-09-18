-- Load project-local .lazy.lua config file (walking up from cwd)
-- Inspired by lazy.nvim's local_spec mechanism.
-- The .lazy.lua file is executed as Lua code (like a normal config file)
-- and can use vim.pack.add(), set options, define keymaps, etc.
--
-- Example .lazy.lua:
--   vim.pack.add { 'https://github.com/user/plugin' }
--   require('plugin').setup { ... }

local LOCAL_FILE = ".lazy.lua"

--- Walk up from cwd to find the nearest .lazy.lua
---@return string|nil file path
local function find_local_spec()
  local path = vim.uv.cwd()
  if not path then
    return nil
  end
  while path and path ~= "" do
    local file = path .. "/" .. LOCAL_FILE
    if vim.fn.filereadable(file) == 1 then
      return file
    end
    local parent = vim.fn.fnamemodify(path, ":h")
    if parent == path then
      break
    end
    path = parent
  end
end

local spec_path = find_local_spec()
if spec_path then
  -- vim.secure.read() will prompt user to trust the file on first access
  local ok, data = pcall(vim.secure.read, spec_path)
  if ok and data then
    local chunk, parse_err = loadstring(data, spec_path)
    if chunk then
      local ok_load, load_err = pcall(chunk)
      if not ok_load then
        vim.notify(
          string.format(".lazy.lua: error executing %s: %s", spec_path, load_err),
          vim.log.levels.ERROR,
          { title = ".lazy.lua" }
        )
      end
    else
      vim.notify(
        string.format(".lazy.lua: error parsing %s: %s", spec_path, parse_err),
        vim.log.levels.ERROR,
        { title = ".lazy.lua" }
      )
    end
  else
    -- User declined trust or read failed, nothing to do
  end
end
