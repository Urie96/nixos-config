local M = {}

---@param buf? number
local function close_terminal_win(buf)
  local win = buf and buf > 0 and vim.b[buf].scratch_terminal_win or vim.b.scratch_terminal_win
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, false)
    vim.b.scratch_terminal_win = nil
  end
end

---@param cmd string[]
---@param opts? table
local function terminal_run(cmd, opts)
  if vim.bo.modified then vim.cmd 'noa write' end
  close_terminal_win()
  local terminal = Snacks.win.new { position = 'bottom', enter = false }
  vim.b.scratch_terminal_win = terminal.win
  opts = opts or {}
  opts.term = true
  vim.api.nvim_buf_call(terminal.buf, function() vim.fn.jobstart(cmd, opts) end)
end

---@class util.scratch.Config
---@field name? string
---@field ft string
---@field ext? string
---@field template? string
---@field main? string
---@field keys? table
---@field init? fun(ctx: table)

---@return util.scratch.Config[]
function M.list()
  ---@type (util.scratch.Config|string)[]
  local config = {
    'json',
    'txt',
    'yaml',
    'http',
    {
      ft = 'markdown',
      ext = 'md',
    },
    {
      ft = 'go',
      keys = {
        {
          '<cr>',
          function(ctx) terminal_run({ 'bash', '-c', 'go mod tidy && go run .' }, { cwd = ctx.root }) end,
        },
      },
    },
    {
      ft = 'mermaid',
      ext = 'mmd',
      init = function(ctx)
        local task = require('overseer').new_task { cmd = { 'live-mermaid', ctx.path } }
        task:start()
      end,
    },
    {
      ft = 'bash',
      ext = 'sh',
      keys = {
        {
          '<cr>',
          function(ctx) terminal_run { 'bash', ctx.path } end,
        },
      },
    },
    {
      ft = 'nu',
      name = 'nushell',
      keys = {
        {
          '<cr>',
          function(ctx) terminal_run { 'nu', ctx.path } end,
        },
      },
    },
    {
      ft = 'lua',
      keys = {
        { '<cr>', function(ctx) Snacks.debug.run { buf = ctx.buf } end },
      },
    },
    {
      ft = 'python',
      ext = 'py',
      keys = {
        {
          '<cr>',
          function(ctx) terminal_run { 'python', ctx.path } end,
        },
      },
    },
    {
      ft = 'javascript',
      ext = 'js',
      keys = {
        {
          '<cr>',
          function(ctx) terminal_run { 'node', ctx.path } end,
        },
      },
    },
    {
      ft = 'rust',
      ext = 'rs',
      main = 'src/main.rs',
      keys = {
        {
          '<cr>',
          function(ctx) terminal_run({ 'cargo', 'run' }, { cwd = ctx.root }) end,
        },
      },
    },
    {
      ft = 'c',
      main = 'src/scratch_main.c',
      keys = {
        {
          '<cr>',
          function(ctx) terminal_run({ 'make', 'run' }, { cwd = ctx.root }) end,
        },
      },
    },
  }
  local list = vim.tbl_map(function(item)
    item = type(item) == 'string' and { ft = item } or item
    if type(item) == 'table' then
      item.name = item.name or item.ft
      item.ext = item.ext or item.ft
      item.main = item.main or string.format('scratch_main.%s', item.ext)
      return item
    end
  end, config)
  local current_ft = vim.bo.filetype
  local current_ext = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':e')
  local top1
  for i, item in pairs(list) do
    if item.ft == current_ft then
      top1 = table.remove(list, i)
      break
    end
  end
  table.insert(list, 1, top1 or {
    ft = current_ft,
    name = current_ft,
    ext = current_ext,
    main = string.format('scratch.%s', current_ext),
  })
  return list
end

function M.select()
  local cwd = vim.uv.cwd() or ''
  local storage_dir = vim.fs.joinpath(vim.fn.stdpath 'data', 'scratch_buffer')
  if vim.fn.isdirectory(storage_dir) == 0 then vim.fn.mkdir(storage_dir, 'p') end

  vim.ui.select(M.list(), {
    prompt = 'Select scratch file type',
    format_item = function(item)
      local icon = Snacks.util.icon(item.ft, 'filetype')
      return string.format('%s  %s', icon, item.name)
    end,
  }, function(selected)
    if not selected then return end
    ---@type util.scratch.Config
    local item = selected
    local dirpath = vim.fs.joinpath(storage_dir, string.format('%s_%s', vim.fn.sha256(cwd), item.name))
    if vim.fn.isdirectory(dirpath) == 0 then
      vim.fn.mkdir(dirpath, 'p')
      local source = vim.fs.joinpath(vim.g.config_directory, 'templates', item.name)
      os.execute('cp -r ' .. source .. '/* ' .. dirpath)
    end
    local filepath = vim.fs.joinpath(dirpath, item.main)
    vim.cmd.edit(filepath)

    local buf = vim.api.nvim_get_current_buf()
    local ctx = { buf = buf, path = filepath, root = dirpath }
    if item.keys then
      for _, key in ipairs(item.keys) do
        local lhs = key[1]
        local rhs = key[2]
        key[1] = nil
        key[2] = nil
        if type(rhs) == 'function' then
          local orig = rhs
          rhs = function() orig(ctx) end
        end
        local mode = key.mode or 'n'
        key.mode = nil
        key.buffer = buf
        vim.keymap.set(mode, lhs, rhs, key)
      end
    end
    vim.api.nvim_create_autocmd('BufHidden', {
      group = vim.api.nvim_create_augroup('scratch_bufhidden_' .. buf, { clear = true }),
      buffer = buf,
      callback = function(ev) close_terminal_win(ev.buf) end,
    })
    if item.init then item.init(ctx) end
  end)
end

return M
