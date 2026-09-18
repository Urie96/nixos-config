local M = {}

function M.show_temporary_popup(text)
  -- 计算窗口大小
  local lines = vim.split(text, '\n')
  local max_line_length = 0
  for _, line in ipairs(lines) do
    max_line_length = math.max(max_line_length, vim.fn.strdisplaywidth(line))
  end
  local width = math.min(max_line_length, vim.o.columns - 4) -- 限制最大宽度
  local height = #lines

  -- 创建浮动窗口配置
  local win_opts = {
    relative = 'cursor',
    row = 1, -- 在光标下方显示
    col = 0,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    focusable = false, -- 重要：窗口不可聚焦
    noautocmd = true, -- 不触发自动命令
  }

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, win_opts)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })

  -- 自动关闭逻辑
  local close_events = { 'CursorMoved', 'CursorMovedI', 'InsertEnter', 'BufLeave', 'ModeChanged' }

  local autoclose = vim.api.nvim_create_augroup('TempPopupAutoclose', { clear = true })
  vim.api.nvim_create_autocmd(close_events, {
    group = autoclose,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      vim.api.nvim_del_augroup_by_id(autoclose)
    end,
    once = true,
  })
end

return M
