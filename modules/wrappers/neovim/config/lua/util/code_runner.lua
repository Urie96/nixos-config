local util_vim = require 'util.vim'

local tbl_alias = {
  python = 'py',
}

local function run(start_ln, end_ln)
  local content = vim.api.nvim_buf_get_lines(0, start_ln - 1, end_ln, true)
  local code_str = table.concat(content, '\n')

  local filetype = vim.bo.filetype
  if not filetype or filetype == '' then filetype = util_vim.set_filetype() end

  local tmp = vim.fn.tempname() .. '.' .. (tbl_alias[filetype] or filetype)
  local file = io.open(tmp, 'w')
  if not file then
    vim.notify('failed to write tmp file', vim.log.levels.ERROR)
    return
  end
  file:write(code_str)
  file:close()

  local terminal = Snacks.terminal.open({ 'run-code', tmp }, { interactive = false })
  terminal:on('TermClose', function() os.remove(tmp) end)
end

return run
