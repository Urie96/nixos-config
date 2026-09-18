Config.on_keys({ '<leader>du' }, function()
  vim.cmd.packadd 'nvim-dap'
  vim.cmd.packadd 'nvim-dap-ui'
  vim.cmd.packadd 'nvim-nio'
  vim.cmd.packadd 'nvim-dap-go'

  local sign_define = function(name, icon, texthl, hl)
    vim.fn.sign_define(name, { text = icon, texthl = texthl, linehl = hl, numhl = hl })
  end
  sign_define('DapStopped', '󰁕 ', 'DiagnosticWarn', 'DapStoppedLine')
  sign_define('DapBreakpoint', ' ')
  sign_define('DapBreakpointCondition', ' ')
  sign_define('DapBreakpointRejected', ' ', 'DiagnosticError')
  sign_define('DapLogPoint', '.>')

  local dapui = require 'dapui'
  local dap = require 'dap'
  local dapgo = require 'dapgo'
  dapui.setup()
  dapgo.setup {}
  dap.listeners.before.attach.dapui_config = function() dapui.open() end
  dap.listeners.before.launch.dapui_config = function() dapui.open() end
  dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
  dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

  vim.keymap.set('n', '<leader>du', function() dapui.toggle {} end, { desc = 'Dap UI' })
  vim.keymap.set({ 'n', 'v' }, '<leader>de', function() dapui.eval() end, { desc = 'Eval' })

  vim.keymap.set(
    'n',
    '<leader>dB',
    function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end,
    { desc = 'Breakpoint Condition' }
  )
  vim.keymap.set('n', '<leader>db', function() dap.toggle_breakpoint() end, { desc = 'Toggle Breakpoint' })
  vim.keymap.set('n', '<leader>dc', function() dap.continue() end, { desc = 'Run/Continue' })
  vim.keymap.set('n', '<leader>dC', function() dap.run_to_cursor() end, { desc = 'Run to Cursor' })
  vim.keymap.set('n', '<leader>dg', function() dap.goto_() end, { desc = 'Go to Line (No Execute)' })
  vim.keymap.set('n', '<leader>di', function() dap.step_into() end, { desc = 'Step Into' })
  vim.keymap.set('n', '<leader>do', function() dap.step_out() end, { desc = 'Step Out' })
  vim.keymap.set('n', '<leader>dk', function() dap.step_over() end, { desc = 'Step Over' })
  vim.keymap.set('n', '<leader>dP', function() dap.pause() end, { desc = 'Pause' })
  vim.keymap.set('n', '<leader>dr', function() dap.repl.toggle() end, { desc = 'Toggle REPL' })
  vim.keymap.set('n', '<leader>ds', function() dap.session() end, { desc = 'Session' })
  vim.keymap.set('n', '<leader>dt', function() dap.terminate() end, { desc = 'Terminate' })
  vim.keymap.set('n', '<leader>dw', function() require('dap.ui.widgets').hover() end, { desc = 'Widgets' })
end)
