if vim.g.vscode then return end
vim.loader.enable() -- Enable faster startup by caching compiled Lua modules

require 'config.options'
require 'config.func'

require 'plugins.global_var'

require 'plugins.snacks'
require 'plugins.treesitter'
require 'plugins.mini'
require 'plugins.ui'
require 'plugins.workflow'
require 'plugins.lsp'
require 'plugins.coding'
require 'plugins.optional'
require 'plugins.dap'
require 'plugins.lint'
require 'plugins.ai'

require 'config.keymaps'
require 'config.autocmds'
require 'config.commands'

require 'config.local_spec'
