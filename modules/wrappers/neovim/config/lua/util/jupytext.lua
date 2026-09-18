local M = {}

function M.precheck()
  if vim.fn.executable 'jupytext' == 0 then
    vim.notify('`jupytext` is not installed', vim.log.levels.WARN)
    return false
  end
  return true
end

function M.read_from_ipynb(bufnr)
  local ipynb_filepath = vim.api.nvim_buf_get_name(bufnr)

  local function fallback_json()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(ipynb_filepath))
    vim.bo[bufnr].filetype = 'json'
    return false
  end

  if not M.precheck() then
    fallback_json()
    return false
  end

  local proc = vim.system({ 'jupytext', ipynb_filepath, '--to', 'py', '--output', '-' }):wait()
  if proc.stderr ~= '' then vim.notify(proc.stderr, proc.code > 0 and vim.log.levels.ERROR or nil) end
  if proc.code > 0 then
    fallback_json()
    return false
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(proc.stdout, '\n'))
  vim.bo[bufnr].filetype = 'python'
  return true
end

function M.write_to_ipynb(bufnr)
  local ipynb_filepath = vim.api.nvim_buf_get_name(bufnr)

  if vim.bo[bufnr].filetype ~= 'python' then -- not handle by jupytext
    vim.cmd.write { ipynb_filepath, bang = true }
    return false
  end

  if not M.precheck() then return end

  local proc = vim
    .system({ 'jupytext', '--from', 'py', '--to', 'ipynb', '--output', ipynb_filepath, '--update' }, {
      stdin = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    })
    :wait()
  if proc.stderr ~= '' then vim.notify(proc.stderr, proc.code > 0 and vim.log.levels.ERROR or nil) end
  if proc.code == 0 then
    vim.bo.modified = false
    return true
  end
  return false
end

return M
