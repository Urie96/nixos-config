Config.later(function()
  vim.cmd.packadd 'nvim-lint'

  local lint = require 'lint'
  lint.linters_by_ft = {
    fish = { 'fish' },
    markdown = { 'markdownlint' },
    -- sh = { "shellcheck" },
    -- bash = { "shellcheck" },
    -- dockerfile = { "shellcheck" },
    dockerfile = { 'hadolint' },
    sql = { 'sqlfluff' },
  }
  lint.try_lint()
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
    group = vim.api.nvim_create_augroup('nvim-lint', { clear = true }),
    callback = function() lint.try_lint() end,
  })
end)
