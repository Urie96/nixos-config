-- Define main config table to be able to pass data between scripts
_G.Config = {}

-- Loading helpers
local misc = require 'mini.misc'
Config.now = function(f) misc.safely('now', f) end
Config.later = function(f) misc.safely('later', f) end
Config.now_if_args = vim.fn.argc(-1) > 0 and Config.now or Config.later
Config.on_event = function(ev, f) misc.safely('event:' .. ev, f) end
Config.on_filetype = function(ft, f) misc.safely('filetype:' .. ft, f) end

-- Define custom autocommand group
local gr = vim.api.nvim_create_augroup('custom-config', {})
Config.new_autocmd = function(event, pattern, callback, desc)
  local opts = { group = gr, pattern = pattern, callback = callback, desc = desc }
  vim.api.nvim_create_autocmd(event, opts)
end

-- Define custom `vim.pack.add()` hook helper
Config.on_packchanged = function(plugin_name, kinds, callback, desc)
  local f = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if not (name == plugin_name and vim.tbl_contains(kinds, kind)) then return end
    if not ev.data.active then vim.cmd.packadd(plugin_name) end
    callback(ev.data)
  end
  Config.new_autocmd('PackChanged', '*', f, desc)
end

Config.on_keys = function(keys, mode, callback)
  if type(mode) == 'function' then
    callback = mode
    mode = 'n'
  end
  if type(mode) == 'string' then mode = { mode } end

  local loaded = false

  for _, lhs in ipairs(keys) do
    for _, m in ipairs(mode) do
      vim.keymap.set(m, lhs, function()
        pcall(vim.keymap.del, m, lhs)

        if not loaded then
          loaded = true
          misc.safely('now', callback)
        end

        local feed_lhs = m:sub(-1) == 'a' and lhs .. '<C-]>' or lhs
        local feed = vim.api.nvim_replace_termcodes('<Ignore>' .. feed_lhs, true, true, true)
        vim.api.nvim_feedkeys(feed, 'i', false)
      end, { expr = true })
    end
  end
end

Config.on_cmd = function(cmds, callback)
  local loaded = false

  for _, cmd in ipairs(cmds) do
    vim.api.nvim_create_user_command(cmd, function(event)
      for _, name in ipairs(cmds) do
        pcall(vim.api.nvim_del_user_command, name)
      end

      if not loaded then
        loaded = true
        misc.safely('now', callback)
      end

      vim.cmd {
        cmd = cmd,
        bang = event.bang or nil,
        args = event.fargs,
      }
    end, { bang = true, nargs = '*' })
  end
end

Config.once = function(f)
  local done = false
  return function()
    if not done then
      done = true
      f()
    end
  end
end

Config.set_keymap = function(arg)
  local mode = arg.mode or 'n'
  local lhs = arg[1]
  local rhs = arg[2]
  arg.mode = nil
  arg[1] = nil
  arg[2] = nil
  vim.keymap.set(mode, lhs, rhs, arg)
end
