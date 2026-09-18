local function map(mode, key, rhs, opt)
  vim.keymap.set(mode, key, rhs, vim.tbl_extend('force', { buffer = 0, nowait = true, silent = true }, opt))
end

map('n', '<CR>', function() require('kulala').run() end, { desc = 'Execute the request' })
map('n', '<leader>i', function() require('kulala').inspect() end, { desc = 'Inspect the current request' })
map('n', 'jj', function() require('kulala').jump_prev() end, { desc = 'Jump to the previous request' })
map('n', 'll', function() require('kulala').jump_next() end, { desc = 'Jump to the next request' })
map('n', '<leader>co', function() require('kulala').copy() end, { desc = 'Copy as curl' })
map('n', '<leader>ss', function() require('kulala').search() end, { desc = 'Search all named requests' })
map('n', '<leader>se', function() require('kulala').set_selected_env() end, { desc = 'Search environment' })
map('n', '<leader>ci', function() require('kulala').from_curl() end, { desc = 'Jump to the next request' })
