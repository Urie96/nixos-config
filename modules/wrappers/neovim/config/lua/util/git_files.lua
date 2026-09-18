local M = {}

local get_color = (function()
  local colors = { 'Constant', 'Statement', 'Keyword', 'String', 'Directory' }
  local i = 0
  local last_key = ''
  return function(key)
    if key ~= last_key then
      last_key = key
      i = i % #colors + 1
    end
    return colors[i]
  end
end)()

--- Run a git command synchronously and return its stdout on success.
--- @param args string[] git arguments, without the leading `git`
--- @param cwd? string
--- @return string?
local function git(args, cwd)
  local cmd = { 'git', '-c', 'core.quotepath=false', '--no-pager' }
  vim.list_extend(cmd, args)
  local ret = vim.system(cmd, { text = true, cwd = cwd }):wait()
  if ret.code ~= 0 then return nil end
  return ret.stdout
end

--- Files matching these patterns are ignored (same as the old `grep -Ev`)
local ignore_patterns = { 'kitex_gen', 'go%.mod', 'go%.sum' }

--- @param path string
local function ignored(path)
  for _, pat in ipairs(ignore_patterns) do
    if path:find(pat) then return true end
  end
  return false
end

--- @param items snacks.picker.finder.Item[]
--- @param sha string
--- @param mod string
--- @param path string repo-relative path
--- @param root string git top level
local function add(items, sha, mod, path, root)
  if path == '' or path:sub(-1) == '/' then return end -- hide directory
  if ignored(path) then return end
  if mod == 'D' or mod == 'AD' then return end -- hide delete
  local file = root .. '/' .. path
  items[#items + 1] = { text = file, file = file, mod = mod, sha = sha }
end

--- Uncommitted files, was `git status --porcelain=v1 -uall` piped through `grep`/`read`
--- @param items snacks.picker.finder.Item[]
--- @param root string
local function add_worktree_files(items, root)
  local out = git({ 'status', '--porcelain=v1', '-uall', '-z' }, root)
  if not out then return end
  local fields = vim.split(out, '\0', { plain = true })
  local i = 1
  while i <= #fields do
    local mod, path = fields[i]:match '^(..) (.*)$'
    if mod then
      -- with `-z` the source path of a rename/copy is the next field
      if mod:find('R') or mod:find('C') then i = i + 1 end
      add(items, 'uncommit', (mod:gsub(' ', '')), path, root)
    end
    i = i + 1
  end
end

--- Files changed by my last commits, was the `git diff-tree` loop in `git-file`
--- @param items snacks.picker.finder.Item[]
--- @param root string
local function add_commit_files(items, root)
  local out = git({
    'log',
    '-10',
    '--no-merges',
    '--author=yangrui',
    '--author=urie',
    '--author=杨锐',
    '--name-status',
    '--no-renames',
    '--diff-filter=d',
    '--format=%x1e%H', -- record separator, so one `git log` is enough
    '-r',
  }, root)
  if not out then return end
  local sha
  for line in vim.gsplit(out, '\n') do
    if line:sub(1, 1) == '\30' then
      sha = line:sub(2, 9) -- 8 chars, same as the old `${sha:0:8}`
    else
      local mod, path = line:match '^(%u)\t(.*)$'
      if mod and sha then add(items, sha, mod, path, root) end
    end
  end
end

local function git_file_finder(_, ctx)
  local cwd = ctx:cwd()
  local root = git({ 'rev-parse', '--show-toplevel' }, cwd)
  root = root and vim.trim(root) or nil
  if not root or root == '' then
    vim.notify('not in git repo', vim.log.levels.ERROR)
    return {}
  end

  local items = {} ---@type snacks.picker.finder.Item[]
  add_worktree_files(items, root)
  add_commit_files(items, root)
  return items
end

local commit_info_cache = require('util.cache').new()
local function relative_date_desc(sha)
  return commit_info_cache:ensure(sha, function()
    local proc = vim.system({ 'git', 'show', sha, '--quiet', '--pretty=format:%at' }, { text = true }):wait()
    return proc and proc.code == 0 and proc.stdout and Util.relative_date_desc(tonumber(proc.stdout) or 0)
  end)
end

local function git_file_formatter(item, picker)
  local base = require('snacks.picker.format').file(item, picker)

  local color = get_color(item.sha)
  local a = Snacks.picker.util.align
  local desc = item.sha and item.sha ~= 'uncommit' and relative_date_desc(item.sha) or '-'
  local ret = {
    { a(desc, 10), color },
    { a(item.mod, 3), color },
  }
  return vim.list_extend(ret, base)
end

local function git_file_previewer(ctx)
  local item = ctx.item
  local cmd
  local git_diff_cmd = function(cmds)
    return vim.list_extend(
      -- { 'git', '--no-pager', '-c', 'diff.external=difft --display=inline --syntax-highlight=off' },
      { 'git', '-c', 'core.pager=delta --pager=never', 'diff', '-w', '--ignore-blank-lines', '-U10' },
      cmds
    )
  end
  if item.mod == '??' then
    return require('snacks.picker.preview').file(ctx)
  elseif item.sha == 'uncommit' then
    cmd = git_diff_cmd { 'HEAD', '--', item.file }
  else
    cmd = git_diff_cmd { item.sha .. '^', item.sha, '--', item.file }
  end
  return require('snacks.picker.preview').cmd(cmd, ctx)
end

local function confirm(picker, _, action)
  local items = picker:selected { fallback = true }
  require('snacks.picker.actions').jump(picker, _, action)
  if #items == 0 then return end

  local item = items[1]
  if item.mod == '??' then return end

  local cmd = {}
  if item.sha == 'uncommit' then
    cmd = { 'git', '--no-pager', 'diff', '-U0', 'HEAD', '--', item.file }
  else
    cmd = { 'git', '--no-pager', 'diff', '-U0', item.sha .. '^', item.sha, '--', item.file }
  end

  local jump_rows = {}
  for _, line in ipairs(vim.fn.systemlist(cmd)) do
    local num = line:match '^@@ %-(%d+)'
    if num and num ~= '' then table.insert(jump_rows, tonumber(num)) end
  end
  if not jump_rows or #jump_rows == 0 then
    vim.notify('No change', vim.log.levels.WARN)
    return
  end

  vim.defer_fn(function()
    local win = picker.main
    local buf = vim.api.nvim_win_get_buf(win) -- TODO: check path

    local jump_pos = function(forward)
      local line = vim.api.nvim_win_get_cursor(win)[1]
      if forward then
        for i = 1, #jump_rows do
          if line < jump_rows[i] then
            vim.api.nvim_win_set_cursor(win, { jump_rows[i], 0 })
            return
          end
        end
        vim.notify('No more changes', vim.log.levels.WARN)
      else
        for i = #jump_rows, 1, -1 do
          if line > jump_rows[i] then
            vim.api.nvim_win_set_cursor(win, { jump_rows[i], 0 })
            return
          end
        end
        vim.notify('No more changes', vim.log.levels.WARN)
      end
    end

    vim.keymap.set('n', 'jc', function() jump_pos(false) end, { buffer = buf, desc = 'Jump to previous change' })
    vim.keymap.set('n', 'lc', function() jump_pos(true) end, { buffer = buf, desc = 'Jump to next change' })

    vim.api.nvim_create_autocmd('BufHidden', {
      group = vim.api.nvim_create_augroup('delete_git_picker_keymap', { clear = true }),
      buffer = buf,
      once = true,
      callback = function()
        vim.keymap.del('n', 'jc', { buffer = buf })
        vim.keymap.del('n', 'lc', { buffer = buf })
      end,
    })
  end, 100)
end

function M.pick()
  Snacks.picker { finder = git_file_finder, format = git_file_formatter, preview = git_file_previewer, confirm = confirm }
end

return M
