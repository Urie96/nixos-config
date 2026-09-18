local M = {}

---@param bufnr integer
---@return string|nil
local function get_cursor_function_name(bufnr)
  local node = vim.treesitter.get_node { bufnr = bufnr }

  while node do
    local node_type = node:type()
    if node_type == 'function_declaration' then break end
    node = node:parent()
  end

  return node and vim.treesitter.get_node_text(node:child(1), bufnr)
end

---@param cmd string[]
local function open(cmd) Snacks.terminal.open(cmd, { interactive = false, win = { position = 'bottom', height = 0.3 } }) end

---@param bufnr integer
local function run_go_test(bufnr)
  local func_name = get_cursor_function_name(bufnr)
  if not func_name or not vim.startswith(func_name, 'Test') then
    vim.notify('Cursor not in test function', vim.log.levels.WARN)
  end
  open { 'go', 'test', '-v', '-run', func_name, './...' }
end

---@param bufnr integer
function M.run_cursor_test(bufnr)
  if not bufnr or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  local ft = vim.bo[bufnr].filetype
  if ft == 'go' then
    run_go_test(bufnr)
  else
    vim.notify(ft .. 'not supported', vim.log.levels.WARN)
  end
end

return M
