vim.api.nvim_create_user_command('Pack', function(opts)
  local pack = require 'util.pack_ui'
  pack.open()
  if opts.args == 'check' then
    pack.check_updates()
  elseif opts.args == 'update' or opts.args == 'update-all' then
    pack.close()
    vim.pack.update()
  end
end, {
  nargs = '?',
  complete = function() return { 'check', 'update', 'update-all' } end,
  desc = 'Open vim.pack plugin manager UI',
})
