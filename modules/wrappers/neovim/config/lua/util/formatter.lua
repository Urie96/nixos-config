local M = {}

---@param cmd string[]
---@param stdin string[]|string
---@param cb fun(out: string[])
local function call_cmd(cmd, stdin, cb)
  if type(stdin) == 'table' then stdin = table.concat(stdin, '\n') end
  vim.system(cmd, { stdin = stdin }, function(out)
    if out.code > 0 then
      vim.notify(
        string.format('`%s` exited with code %d, stderr: %s', table.concat(cmd, ' '), out.code, out.stderr),
        vim.log.levels.ERROR
      )
      return
    end

    vim.notify(string.format('`%s` done!', table.concat(cmd, ' ')))
    local stdout = vim.split(out.stdout, '\n')
    if stdout[#stdout] == '' then stdout[#stdout] = nil end

    cb(stdout)
  end)
end

---@param ctx util.command_picker.ctx
---@param cmd string[]
local function replace_selection(ctx, cmd)
  call_cmd(cmd, ctx.visual.lines, function(stdout)
    local start_row, start_col, end_row, end_col =
      ctx.visual.pos[1] - 1, ctx.visual.pos[2], ctx.visual.end_pos[1] - 1, ctx.visual.end_pos[2] + 1
    vim.schedule(function() vim.api.nvim_buf_set_text(ctx.buf, start_row, start_col, end_row, end_col, stdout) end)
  end)
end

local function replace_buf(buf, cmd)
  local buf_text = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  call_cmd(cmd, buf_text, function(stdout)
    vim.schedule(function() vim.api.nvim_buf_set_lines(buf, 0, -1, false, stdout) end)
  end)
end

---@param ctx util.command_picker.ctx
function M.range_format_json(ctx) replace_selection(ctx, { 'jq', '.' }) end

---@param ctx util.command_picker.ctx
function M.range_minify_json(ctx) replace_selection(ctx, { 'jq', '-c', '.' }) end

---@param bufnr integer
function M.goimports(bufnr) replace_buf(bufnr, { 'goimports' }) end

---@param ctx util.command_picker.ctx
function M.range_fix_golines(ctx) replace_selection(ctx, { 'fmt-file', '-f', 'golines' }) end

---@param ctx util.command_picker.ctx
function M.range_stringify(ctx) replace_selection(ctx, { 'jq', '-Rs', '.' }) end

---@param ctx util.command_picker.ctx
function M.range_unstringify(ctx) replace_selection(ctx, { 'jq', '-r', '.' }) end

---@param ctx util.command_picker.ctx
function M.url_decode(ctx)
  replace_selection(
    ctx,
    { 'python', '-c', 'import sys; from urllib.parse import unquote; print(unquote(sys.stdin.read()));' }
  )
end

---@param ctx util.command_picker.ctx
function M.url_encode(ctx)
  replace_selection(
    ctx,
    { 'python', '-c', 'import sys; from urllib.parse import quote; print(quote(sys.stdin.read(), safe=""));' }
  )
end

---@param ctx util.command_picker.ctx
function M.join_string_array(ctx) replace_selection(ctx, { 'jq', '-r', 'join("")' }) end

---@param buf integer
---@param opts? { async: boolean?, code_action: boolean? }
function M.format_buf(buf, opts)
  opts = opts or {}
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then return end
  local cmd = { 'fmt-file' }
  local ft = vim.bo[buf].filetype
  if ft ~= '' then
    table.insert(cmd, '-l')
    table.insert(cmd, ft)
  end
  local bufname = vim.api.nvim_buf_get_name(buf)
  local basename = vim.fs.basename(bufname)
  if basename ~= '' then
    table.insert(cmd, '-n')
    table.insert(cmd, basename)
  end
  if opts.async and opts.code_action then
    vim.notify('Cannot use async and code_action at the same time', vim.log.levels.ERROR)
    return
  end
  if opts.async then
    replace_buf(buf, cmd)
  else
    if opts.code_action then
      if ft == 'go' then M.sync_run_code_actions({ 'source.organizeImports' }, buf, 3000) end
      if ft == 'python' then M.sync_run_code_actions({ 'source.organizeImports' }, buf, 3000) end
    end
    local orig_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, true), '\n')
    local obj = vim.system(cmd, { text = true, timeout = 3000, stdin = orig_content }):wait()
    if obj.stderr ~= '' then
      vim.notify(string.format('Format error:\n %s', obj.stderr), vim.log.levels.ERROR)
      return
    end
    if obj.stdout ~= '' then
      local final_content = vim.trim(obj.stdout)
      if final_content == orig_content then return end
      vim.api.nvim_buf_set_lines(buf, 0, -1, true, vim.split(final_content, '\n'))
    end
  end
end

---@param timestamp number
---@return string
function M.format_timestamp(timestamp)
  local current_time = os.time()
  local time_diff = timestamp - current_time -- 现在计算未来时间的差值
  local formatted_time = os.date('%Y-%m-%d %H:%M:%S', timestamp)

  -- 计算时间差描述
  local time_desc
  local absolute_diff = math.abs(time_diff)
  local suffix = time_diff > 0 and '后' or '前'

  if absolute_diff < 60 then
    time_desc = '刚刚'
  elseif absolute_diff < 3600 then
    local minutes = math.floor(absolute_diff / 60)
    time_desc = minutes .. '分钟' .. suffix
  elseif absolute_diff < 86400 then
    local hours = math.floor(absolute_diff / 3600)
    time_desc = hours .. '小时' .. suffix
  elseif absolute_diff < 2592000 then
    local days = math.floor(absolute_diff / 86400)
    time_desc = days .. '天' .. suffix
  elseif absolute_diff < 31536000 then
    local months = math.floor(absolute_diff / 2592000)
    time_desc = months .. '个月' .. suffix
  else
    local years = math.floor(absolute_diff / 31536000)
    time_desc = years .. '年' .. suffix
  end

  return string.format('%s (%s)', formatted_time, time_desc)
end

---@param action table
---@param buf integer
---@param timeout_ms integer
---@param attempts integer
local function handle_action_sync(action, buf, timeout_ms, attempts)
  if attempts > 3 then
    vim.notify('Max resolve attempts reached for action ' .. action.kind, vim.log.levels.WARN)
    return
  end

  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, 'utf-16')
  elseif action.command then
    vim.lsp.buf.execute_command(action.command)
  else
    -- neovim:runtime/lua/vim/lsp/buf.lua shows how to run a code action
    -- synchronously. This section is based on that.
    local resolve_result = vim.lsp.buf_request_sync(buf, 'codeAction/resolve', action, timeout_ms)
    if resolve_result then
      for _, resolved_action in pairs(resolve_result) do
        handle_action_sync(resolved_action.result, buf, timeout_ms, attempts + 1)
      end
    else
      vim.notify('Failed to resolve code action ' .. action.kind .. ' without edit or command', vim.log.levels.WARN)
    end
  end
end

---@param kinds string[]
---@param buf integer
---@param timeout_ms integer
function M.sync_run_code_actions(kinds, buf, timeout_ms)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then return end
  local params = vim.lsp.util.make_range_params(0, 'utf-8')
  params.context = { diagnostics = {} }

  local results = vim.lsp.buf_request_sync(buf, 'textDocument/codeAction', params, timeout_ms)
  if not results then return end

  for _, result in pairs(results) do
    for _, action in pairs(result.result or {}) do
      for _, kind in pairs(kinds) do
        if action.kind == kind then handle_action_sync(action, buf, timeout_ms, 0) end
      end
    end
  end
end

return M
