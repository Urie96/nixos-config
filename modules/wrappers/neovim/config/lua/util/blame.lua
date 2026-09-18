local M = {}

local function get_line_last_commit_sha_of(filepath, ln)
  local dirpath = vim.fs.dirname(filepath)
  local filename = vim.fs.basename(filepath)
  local cmd = { 'git', '--no-pager', 'blame', '-l', '-s', '-L', tostring(ln) .. ',+1', '--', filename }
  local proc = vim.system(cmd, { cwd = dirpath, text = true }):wait()
  return proc.stdout and proc.stdout:match '^%S+'
end

---@param win integer
---@param buf integer
function M.show(win, buf)
  local blame_ln = vim.api.nvim_win_get_cursor(win)[1]
  local filepath = vim.api.nvim_buf_get_name(buf)
  local dirpath = vim.fs.dirname(filepath)
  local filename = vim.fs.basename(filepath)

  local blame_cmd = {
    'git',
    '-c',
    "core.pager=delta --pager=never --blame-format=' {timestamp:<15} {author:<15.14}' --wrap-max-lines=0",
    'blame',
    '--',
    filename,
  }

  local terminal = Snacks.terminal.open(blame_cmd, {
    cwd = dirpath,
    interactive = false,
  })
  terminal:on('TermClose', function()
    if type(vim.v.event) == 'table' and vim.v.event.status ~= 0 then
      Snacks.notify.error('Terminal exited with code ' .. vim.v.event.status .. '.\nCheck for any errors.')
      return
    end

    local blame_output_lines = vim.api.nvim_buf_get_lines(terminal.buf, blame_ln - 1, -1, false)
    local pattern = '│%s*' .. tostring(blame_ln) .. '%s*│'
    for i, line in ipairs(blame_output_lines) do
      if string.find(line, pattern) then
        vim.api.nvim_win_set_cursor(terminal.win, { blame_ln + i - 1, 35 })
        break
      end
    end

    vim.keymap.set('n', '<cr>', function()
      local inspect_ln = vim.api.nvim_get_current_line():gmatch '│%s*(%d+)%s*│'()
      if not tonumber(inspect_ln) then
        Snacks.notify.error 'Unable to parse line number'
        return
      end

      local inspect_commit = get_line_last_commit_sha_of(filepath, inspect_ln)
      local inspect_cmd = {
        'git',
        '-c',
        'core.pager=delta --pager=never',
        'log',
        inspect_commit,
        '-w',
        '--ignore-blank-lines',
        '--date=short',
        '-n', -- Limit the number of commits to output.
        '5',
        '-u',
        '-p',
        string.format('%s', filename),
      }
      Snacks.terminal.open(inspect_cmd, { cwd = dirpath, interactive = false })
    end, { buffer = terminal.buf })
  end, { buf = true })
end

return M
