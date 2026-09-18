local ok, nix = pcall(require, 'nix-info')
if ok then
  vim.g.config_directory = nix.settings.config_directory
else
  vim.g.config_directory = vim.fn.stdpath 'config'
end

vim.g.mapleader = ' '
vim.g.maplocalleader = ','
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.cmdheight = 0
vim.opt.laststatus = 3 -- global statusline, keep lualine always bottom

vim.opt.confirm = true -- `:qa` confirm to save if edited
vim.opt.jumpoptions = 'view' -- ctrl-o reopen deleted buffer
vim.opt.expandtab = true -- expand tab input with spaces characters
vim.opt.smartindent = true -- Insert indents automatically
vim.opt.tabstop = 2 -- Number of spaces tabs count for
vim.opt.shiftwidth = 2 -- Size of an indent
vim.opt.winborder = 'rounded'
vim.opt.diffopt:append 'iwhiteall' -- Ignore whitespace changes in diff
vim.opt.diffopt:append 'iblank' -- Ignore blank line in diff

-- fold
vim.opt.foldmethod = 'expr'
vim.opt.foldtext = ''
vim.opt.foldlevel = 99 -- disable auto fold

vim.opt.number = true
vim.opt.mouse = 'a' -- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.showmode = false -- Don't show the mode, since it's already in the status line
vim.schedule(function()
  -- Schedule the setting after `UiEnter` because it can increase startup-time.
  -- only set clipboard if not in ssh, to make sure the OSC 52
  vim.opt.clipboard = vim.env.SSH_TTY and '' or 'unnamedplus' -- Sync with system clipboard
  vim.g.clipboard = vim.env.SSH_TTY and 'osc52' or nil
end)
vim.opt.breakindent = true -- Enable break indent
vim.opt.undofile = true -- Save undo history
vim.opt.grepprg = 'rg --vimgrep'

vim.opt.wildmode = 'longest:full,full' -- Command-line completion mode

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = 'yes' -- Keep signcolumn on by default
vim.opt.updatetime = 200 -- Decrease update time
vim.opt.timeoutlen = 1000 -- Decrease mapped sequence wait time

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.inccommand = 'split' -- Preview substitutions live, as you type!
vim.opt.cursorline = true -- Show which line your cursor is on
vim.opt.scrolloff = 10 -- Minimal number of screen lines to keep above and below the cursor.
vim.opt.wrap = true
vim.opt.conceallevel = 0 -- don't hide my json strings
vim.opt.spelllang = { 'en', 'cjk' }
vim.opt.spelloptions = 'camel'

vim.opt.sessionoptions = { 'buffers', 'curdir', 'winsize', 'help', 'globals', 'skiprtp', 'folds' }

vim.opt.fillchars = {
  foldopen = '',
  foldclose = '',
  fold = ' ',
  foldsep = ' ',
  diff = ' ',
  eob = ' ',
}

vim.opt.title = true -- enable neovim change terminal title
if vim.env.PI_CODING_AGENT then
  vim.opt.titlestring = 'VI:π'
else
  vim.opt.titlestring = "VI:%{fnamemodify(getcwd(), ':t')}"
end

-- https://neovim.io/doc/user/lua.html#vim.filetype.add()
vim.filetype.add {
  extension = {
    service = 'systemd',
    d2 = 'd2',
    http = 'http',
    tmpl = 'gotmpl',
    sh = 'bash',
    rpc = 'rpc',
  },
  filename = {
    ['.envrc'] = 'bash',
  },
}
