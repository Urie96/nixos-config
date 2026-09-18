---@diagnostic disable: missing-fields

local map = Config.set_keymap

local function session_name() return vim.fn.getcwd():gsub('[^%w_-]', '_') end

Config.now(function()
  require('mini.sessions').setup { autowrite = false }

  if vim.fn.argc() == 0 then
    -- 自动命令：在退出前如果没有活动会话，则写一个基于 pwd 的会话
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        if vim.v.this_session == '' then
          require('mini.sessions').write(session_name(), { force = true })
        else
          require('mini.sessions').write(nil, { force = true })
        end
      end,
    })
  end
end)

-- Snacks ================================================================
Config.now(function()
  vim.g.snacks_animate = false -- disable snack animate
  require('snacks').setup {
    image = { enabled = true, doc = { enabled = false }, math = { enabled = true } },
    scroll = { enabled = true },
    indent = { enabled = true, animate = { enabled = false } },
    input = { enabled = true },
    notifier = { enabled = true },
    scope = { enabled = true },
    bigfile = { enabled = true, line_length = 100000 },
    -- quickfile = { enabled = true },
    terminal = {
      win = {
        style = 'float',
        keys = {
          ['<C-_>'] = { 'hide', mode = { 'n', 't' } },
        },
        border = 'rounded',
      },
    },
    picker = {
      enabled = true,
      debug = {
        -- grep = true,
      },
      actions = {
        -- trouble_open = function(...) require('trouble.sources.snacks').actions.trouble_open(...) end,
        exclude = function(picker)
          local old = vim.api.nvim_get_current_line()
          local main_buffer = vim.api.nvim_win_get_buf(picker.main)
          local ext = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(main_buffer), ':e')
          local cwd = vim.uv.cwd() or ''
          local is_work = cwd:find '/work/'

          local picker_name = picker.init_opts.source
          if picker_name == 'grep' then
            local rg_args = {}
            if ext ~= '' then table.insert(rg_args, '-g *.' .. ext) end
            if is_work then table.insert(rg_args, '-g !kitex_gen') end
            if #rg_args > 0 then vim.api.nvim_set_current_line(old .. ' -- ' .. table.concat(rg_args, ' ')) end
          elseif picker_name == 'lsp_references' then
            local args = { old }
            if is_work then table.insert(args, 'file:!kitex_gen') end
            table.insert(args, 'file:^' .. cwd)
            vim.api.nvim_set_current_line(table.concat(args, ' '))
          elseif picker_name == 'smart' then
            local args = { old }
            if ext ~= '' then table.insert(args, 'file:' .. ext .. '$') end
            vim.api.nvim_set_current_line(table.concat(args, ' '))
          end
        end,
      },
      previewers = {
        diff = { builtin = false },
      },
      win = {
        input = {
          keys = {
            ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
            ['<PageDown>'] = { 'preview_scroll_down', mode = { 'i', 'n' } },
            ['<PageUp>'] = { 'preview_scroll_up', mode = { 'i', 'n' } },
            ['<C-i>'] = { 'history_forward', mode = { 'i', 'n' } },
            ['<C-o>'] = { 'history_back', mode = { 'i', 'n' } },
            ['<C-u>'] = false, -- clear input
            ['<C-e>'] = { 'exclude', mode = { 'i' } },
            ['<C-d>'] = { 'delete', mode = { 'i' } },
            ['<C-t>'] = { 'trouble_open', mode = { 'i' } },
          },
        },
      },
    }, -- better vim.ui.select
    -- scroll = { enabled = true },
    statuscolumn = { enabled = false },
    words = { enabled = true },
    dashboard = {
      preset = {
        keys = {
          {
            icon = ' ',
            key = 's',
            desc = 'Restore Session',
            action = ':lua MiniSessions.read("' .. session_name() .. '")',
          },
          { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
          { icon = ' ', key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
          {
            icon = ' ',
            key = 'r',
            desc = 'Recent Files',
            action = function() Snacks.picker.recent { filter = { paths = { [vim.uv.cwd()] = true } } } end,
          },
          { icon = ' ', title = 'Projects', section = 'projects', indent = 2, padding = 1 },
        },
      },
      sections = {
        { section = 'header' },
        { section = 'keys', gap = 1, padding = 1 },
        -- { section = 'startup' },
      },
    },
    lazygit = {},
  }
end)

map { '<leader>ff', function() Snacks.picker.smart { filter = { cwd = true } } end, desc = 'Find Files' }
map { '<leader>lg', function() Snacks.lazygit { cwd = vim.fn.expand '%:h' } end, desc = 'Lazygit' }
map { '<leader>gf', function() Snacks.picker.git_log_file() end, desc = 'Current File Git History' }
map { '<leader>sd', function() Snacks.picker.diagnostics() end, desc = 'Workspace diagnostics' }
map { '<leader>sb', function() Snacks.picker.lines() end, desc = 'Buffer Lines' }
map {
  '<leader>fb',
  function() Snacks.picker.buffers { actions = { delete = Snacks.picker.actions.bufdelete } } end,
  desc = 'Buffers',
}
map {
  '<leader>ss',
  function()
    Snacks.picker.lsp_symbols {
      layout = { preset = 'vscode', preview = 'main' },
      filter = {
        lua = { 'Method', 'Function' },
      },
    }
  end,
}
map { '<leader>n', function() Snacks.picker.notifications() end, desc = 'Notification History' }
map {
  '<C-q>',
  function()
    local bufs = vim.fn.getbufinfo { buflisted = 1 }
    if #bufs > 1 then
      Snacks.bufdelete()
      return
    end
    vim.cmd 'q'
  end,
  mode = { 'n', 'i' },
  desc = 'Close Buffer',
}
map {
  '<leader>bf',
  function()
    local cwd = vim.uv.cwd() or vim.env.PWD
    Snacks.bufdelete {
      filter = function(buf)
        local buf_name = vim.api.nvim_buf_get_name(buf)
        return buf_name ~= '' and not vim.startswith(buf_name, cwd)
      end,
    }
  end,
  desc = 'Delete buffers not in cwd',
}
map { '<leader>bo', function() Snacks.bufdelete.other() end, desc = 'Delete Other Buffers' }
-- map { 'mm', function() Snacks.picker.marks() end, desc = 'List Marks' }
map { '<leader><space>', function() Snacks.picker.grep() end, desc = 'Grep' }
map { '<C-S-O>', function() Snacks.picker.resume() end, desc = 'Resumes Last Picker' }
-- lsp
map { 'gd', function() Snacks.picker.lsp_definitions { jump = { reuse_win = false } } end, desc = '[G]oto [D]efinition' }
map { 'gr', function() Snacks.picker.lsp_references() end, desc = '[G]oto [R]eferences' }
map { 'gI', function() Snacks.picker.lsp_implementations() end, desc = '[G]oto [I]mplementation' }
map { 'lr', function() Snacks.words.jump(vim.v.count1) end, desc = 'Next Reference' }
map { 'jr', function() Snacks.words.jump(-vim.v.count1) end, desc = 'Prev Reference' }
-- terminal
map { '<C-/>', '<C-_>', mode = { 'n', 't' }, remap = true }
map {
  '<C-_>',
  function() Snacks.terminal() end,
  mode = { 'n' },
  desc = 'Terminal (Root Dir)',
}

map {
  '<leader><C-_>',
  function()
    local file_dir = vim.fn.expand '%:h'
    if file_dir and file_dir ~= '' then Snacks.terminal(nil, { cwd = file_dir }) end
  end,
  mode = { 'n' },
  desc = 'Terminal (File Dir)',
}
