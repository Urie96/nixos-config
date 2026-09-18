local map = Config.set_keymap

Config.on_keys({ '<leader>ya' }, function()
  vim.cmd.packadd 'yazi.nvim'

  require('yazi').setup {
    open_for_directories = false,
    floating_window_scaling_factor = 1,
    yazi_floating_window_winblend = 0,
    open_file_function = function(chosen_file)
      if vim.fn.isdirectory(chosen_file) == 1 then
        vim.fn.chdir(chosen_file)
      else
        vim.cmd(string.format('edit %s', vim.fn.fnameescape(chosen_file)))
      end
    end,
    integrations = {
      grep_in_directory = function(directory)
        vim.defer_fn(function()
          -- HACK something seems to exit insert mode when the picker is shown.
          -- Wait a bit to hack around this.
          require('snacks.picker').grep {
            dirs = { directory },
            title = 'Grep in ' .. directory,
          }
        end, 50)
      end,
    },
  }

  vim.keymap.set('n', '<leader>ya', '<cmd>Yazi <cr>', { desc = 'Open yazi at the current file' })
  vim.keymap.set('n', '<leader>yA', '<cmd>Yazi cwd<cr>', { desc = "Open the file manager in nvim's working directory" })
end)

Config.on_filetype('rpc', function()
  vim.pack.add { 'https://github.com/urie96/rpc.nvim' }
  require('rpc').setup {}
end)

Config.on_keys({ '<leader>tr', '<leader>to', '<leader>tO' }, function()
  vim.cmd.packadd 'neotest'
  vim.cmd.packadd 'neotest-nio'
  vim.cmd.packadd 'neotest-golang'

  local neotest = require 'neotest'
  local neotest_go = require 'neotest-golang'

  ---@diagnostic disable: missing-fields
  neotest.setup { adapters = { neotest_go } }

  vim.keymap.set('n', '<leader>tr', function() neotest.run.run() end, { desc = 'Run Nearest (Neotest)' })
  vim.keymap.set(
    'n',
    '<leader>to',
    function() neotest.output.open { enter = true, auto_close = true } end,
    { desc = 'Show Output (Neotest)' }
  )
  vim.keymap.set(
    'n',
    '<leader>tO',
    function() neotest.output_panel.toggle() end,
    { desc = 'Toggle Output Panel (Neotest)' }
  )
end)

Config.on_keys(
  { '<leader>ow', '<leader>on', '<leader>oo', '<leader>ob', '<leader>or', '<leader>ot', '<leader>oq' },
  function()
    vim.cmd.packadd 'overseer.nvim'

    local overseer = require 'overseer'
    overseer.setup {
      task_list = {
        keymaps = {
          ['<C-j>'] = false,
          ['<C-k>'] = false,
          ['<C-l>'] = false,
          ['<C-c>'] = { 'keymap.run_action', opts = { action = 'stop' }, desc = 'Stop task' },
          r = { 'keymap.run_action', opts = { action = 'restart' }, desc = 'Restart task' },
        },
      },
    }

    map { '<leader>ow', '<cmd>OverseerToggle right<cr>', desc = 'Task list' }
    map { '<leader>on', '<cmd>OverseerBuild<cr>', desc = 'New Task' }
    map {
      '<leader>oo',
      function()
        overseer.run_task({}, function(task)
          if task then overseer.open { enter = false, direction = 'right' } end
        end)
      end,
      desc = 'Run task',
    }
    map {
      '<leader>ob',
      function()
        local task = overseer.new_task {
          cmd = { 'just', 'build' },
          components = {
            { 'on_output_quickfix', open_on_exit = 'failure' },
            'default',
          },
        }
        task:start()
      end,
      desc = 'Run just build',
    }
    map { '<leader>or', '<cmd>OverseerQuickAction restart<cr>', desc = 'Restart Last Action' }
    map { '<leader>ot', '<cmd>OverseerTaskAction<cr>', desc = 'Task action' }
    map { '<leader>oq', '<cmd>OverseerQuickAction open output in quickfix<cr>', desc = 'Open QuickFix' }
  end
)
