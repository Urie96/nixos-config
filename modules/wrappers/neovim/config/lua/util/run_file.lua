local M = {}

---@param buf? number
local function close_terminal_win(buf)
  local win = buf and buf > 0 and vim.b[buf].run_file_terminal_win or vim.b.run_file_terminal_win
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, false)
    vim.b.run_file_terminal_win = nil
  end
end

-- shebang detection, order matters (same as the `case` in the old `run-file`)
local shebangs = {
  { 'bash', 'sh' },
  { 'fish', 'fish' },
  { 'node', 'node' },
  { 'python', 'py' },
  { 'sh', 'sh' },
}

--- Extension detection, mirrors the old `run-file` bash script.
--- @param path string
--- @return string?
local function detect_extension(path)
  local name = vim.fn.fnamemodify(path, ':t')
  if not name:find('.', 1, true) then
    local first_line = vim.fn.readfile(path, '', 1)[1] or ''
    for _, s in ipairs(shebangs) do
      if first_line:find(s[1], 1, true) then return s[2] end
    end
    return nil
  end
  local ext = name:match '%.([^%.]*)$'
  return ext and ext:lower()
end

--- Commands to run for a file. Several commands are run in sequence in the
--- same terminal buffer (only needed for go: `go mod tidy` and `go run .`).
--- @param path string
--- @return string[][]? cmds
--- @return string? err
local function commands(path)
  local ext = detect_extension(path)
  if not ext then
    return nil, 'unable to detect language'
  elseif ext == 'lua' then
    return { { 'lua', path } }
  elseif ext == 'js' then
    for _, bin in ipairs { 'node', 'bun', 'deno' } do
      if vim.fn.executable(bin) == 1 then return { { bin, path } } end
    end
    return nil, 'node/bun/deno not found'
  elseif ext == 'go' then
    return { { 'go', 'mod', 'tidy' }, { 'go', 'run', '.' } }
  elseif ext == 'py' then
    return { { 'python3', path } }
  elseif ext == 'sh' then
    return { { 'bash', path } }
  elseif ext == 'fish' then
    return { { 'fish', path } }
  end
  return nil, ("unknown ext: '%s'"):format(ext)
end

function M.run_file()
  local file_buf = vim.api.nvim_get_current_buf()
  if vim.bo.modified then vim.cmd 'noa write' end

  local file_path = vim.api.nvim_buf_get_name(file_buf)
  if file_path == '' then
    vim.notify('run-file: buffer has no name', vim.log.levels.ERROR)
    return
  end

  local cmds, err = commands(file_path)
  if not cmds then
    vim.notify('run-file: ' .. err, vim.log.levels.ERROR)
    return
  end

  close_terminal_win()
  local terminal = Snacks.win.new { position = 'bottom', enter = false }
  vim.b[file_buf].run_file_terminal_win = terminal.win

  local job_id
  vim.api.nvim_buf_call(terminal.buf, function()
    --- start the i-th command in the terminal buffer
    --- @param i number
    local function start(i)
      if not (terminal.win and vim.api.nvim_win_is_valid(terminal.win)) then return end
      vim.bo[terminal.buf].modified = false -- `term = true` requires an unmodified buffer
      job_id = vim.fn.jobstart(cmds[i], {
        term = true,
        cwd = vim.fn.fnamemodify(file_path, ':h'),
        on_stdout = function(_, data, _)
          if data then
            -- 确保光标在最后一行
            local last_line = vim.api.nvim_buf_line_count(terminal.buf)
            vim.api.nvim_win_set_cursor(terminal.win, { last_line, 0 })
          end
        end,
        on_exit = function()
          if i < #cmds then
            vim.api.nvim_buf_call(terminal.buf, function() start(i + 1) end)
          end
        end,
      })
    end
    start(1)

    local ag = vim.api.nvim_create_augroup('run_file_clean_job', { clear = true })
    vim.api.nvim_create_autocmd('WinClosed', {
      group = ag,
      pattern = tostring(terminal.win),
      once = true,
      callback = function()
        if job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1 then
          vim.fn.jobstop(job_id)
          vim.b.run_file_job_id = nil
        end
      end,
    })
  end)
end

return M
