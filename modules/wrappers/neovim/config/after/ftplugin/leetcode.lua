local function map(mode, key, rhs) vim.keymap.set(mode, key, rhs, { buffer = 0, nowait = true, silent = true }) end

map('n', 'K', function() require('util.image').show_hover_image() end)
