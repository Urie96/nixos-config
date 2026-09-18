local M = {}

function M.set_filetype()
  local prompt = 'Set fileType: '
  local old = vim.bo.filetype
  if old and old ~= '' then prompt = 'Replace filetype from ' .. old .. ' to: ' end
  local filetype = vim.fn.input(prompt)
  if filetype ~= '' then
    vim.bo.filetype = filetype
    return filetype
  end
end

---@param path string
---@param row integer
---@param col integer
function M.jump_to(path, row, col)
  local bufnr = vim.fn.bufnr('^' .. path .. '$')
  if bufnr == -1 then bufnr = vim.fn.bufadd(path) end
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
    vim.api.nvim_set_option_value('buflisted', true, {
      buf = bufnr,
    })
  end

  vim.api.nvim_set_current_buf(bufnr)
  local lines = vim.api.nvim_buf_line_count(bufnr)
  if row and row > lines then row = lines end
  vim.api.nvim_win_set_cursor(0, {
    row or 1,
    col or 0,
  })
end

local function ts_highlighter(bufnr, ft)
  if ft and ft ~= '' then
    local lang = vim.treesitter.language.get_lang(ft) or ft
    local has_ts_parser = pcall(vim.treesitter.language.add, lang)
    if has_ts_parser then return vim.treesitter.start(bufnr, lang) end
  end
  return false
end

local function regex_highlighter(bufnr, ft)
  if ft and ft ~= '' then return pcall(vim.api.nvim_set_option_value, 'syntax', ft, { buf = bufnr }) end
  return false
end

function M.highlight_buffer(bufnr, ft) return ts_highlighter(bufnr, ft) or regex_highlighter(bufnr, ft) end

---@alias util.visual {pos: integer[],end_pos: integer[], lines: string[]}

---@return util.visual|nil
function M.get_visual()
  local modes = { 'v', 'V', vim.api.nvim_replace_termcodes('<C-v>', true, true, true) }
  local mode = vim.fn.mode():sub(1, 1) ---@type string
  if not vim.tbl_contains(modes, mode) then return end
  -- stop visual mode
  vim.cmd('normal! ' .. mode)

  local pos = vim.api.nvim_buf_get_mark(0, '<')
  local end_pos = vim.api.nvim_buf_get_mark(0, '>')

  -- for some reason, sometimes the column is off by one
  -- see: https://github.com/folke/snacks.nvim/issues/190
  local col_to = math.min(end_pos[2] + 1, #vim.api.nvim_buf_get_lines(0, end_pos[1] - 1, end_pos[1], false)[1])

  local lines = vim.api.nvim_buf_get_text(0, pos[1] - 1, pos[2], end_pos[1] - 1, col_to, {})
  end_pos[2] = math.max(0, col_to - 1) -- me: fix end_pos=2147483647
  return {
    pos = pos,
    end_pos = end_pos,
    lines = lines,
  }
end

function M.show_tip(text)
  vim.schedule(function()
    local lines = vim.split(vim.trim(text), '\n')
    local max_width = 0
    for _, v in ipairs(lines) do
      local w = vim.api.nvim_strwidth(v)
      if w > max_width then max_width = w end
    end

    local w = Snacks.win {
      relative = 'cursor',
      backdrop = false,
      row = 1,
      col = 0,
      width = max_width + 2,
      height = #lines,
      border = 'rounded',
      text = lines,
      focusable = false, -- 不可交互，点击自动关闭
      wo = {
        wrap = true,
        linebreak = true,
      },
    }

    -- 监听光标移动和按键自动关闭
    w:on('CursorMoved', function() w:close() end)
    w:on('CursorMovedI', function() w:close() end)
  end)
end

return M
