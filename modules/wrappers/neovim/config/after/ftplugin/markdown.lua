local function map(mode, key, rhs) vim.keymap.set(mode, key, rhs, { buffer = 0, nowait = true, silent = true }) end

-- map({ 'n', 'x' }, 'K', function() Snacks.image.hover() end)
map('n', 'K', function() require('util.image').show_hover_image() end)

vim.b.iminsert = true
-- vim.b.enable_auto_rime = true
