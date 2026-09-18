local M = {}

--- Check if cursor is in treesitter capture
---@param capture string | []string
---@return boolean
function M.cursor_in_capture(capture)
  local captures_at_cursor = vim.treesitter.get_captures_at_cursor()
  if vim.tbl_isempty(captures_at_cursor) then
    return false
  elseif type(capture) == 'string' and vim.tbl_contains(captures_at_cursor, capture) then
    return true
  elseif type(capture) == 'table' then
    for _, v in ipairs(capture) do
      if vim.tbl_contains(captures_at_cursor, v) then return true end
    end
  end
  return false
end

local jump_function_name_config = {
  common = {
    method_declaration = 'name',
    function_declaration = 'name',
    function_definition = 'name',
  },
  go = {
    func_literal = 'parameters',
  },
  lua = {
    function_definition = 'parameters',
  },
  nu = {
    decl_def = 'unquoted_name',
  },
  rust = {
    function_item = 'name',
  },
}

--- @param node TSNode
--- @param to_end? boolean
function M.goto_node(node, to_end)
  local start_row, start_col, end_row, end_col = node:range()
  local dest_row = (to_end and end_row or start_row) + 1
  local dest_col = to_end and (end_col - 1) or start_col
  vim.cmd "normal! m'" -- set jump list so I can jump back
  vim.api.nvim_win_set_cursor(0, { dest_row, dest_col })
end

function M.jump_function_name()
  local node = vim.treesitter.get_node()
  local config =
    vim.tbl_deep_extend('force', jump_function_name_config.common, jump_function_name_config[vim.bo.filetype] or {})

  if not config then config = {} end

  while node do
    local name = config[node:type()]

    if name then
      local name_node = node:field(name)[1]
      if name_node then
        M.goto_node(name_node)
        return
      end
    end

    node = node:parent()
  end
end

-- 判断是否为注释容器节点（排除 comment_content 等子节点）
local function is_comment_container(t)
  -- 精确匹配常见的注释容器类型
  local exact = {
    comment = true,
    line_comment = true,
    block_comment = true,
    doc_comment = true,
    documentation_comment = true,
    html_comment = true,
    multiline_comment = true,
  }
  return exact[t] or false
end

-- 获取光标所在连续注释块的全部内容（跨行）
function M.get_comment_block()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  -- 1. 获取光标处节点
  local node = vim.treesitter.get_node { buf = buf, pos = { row, col } }
  if not node then
    local parser = vim.treesitter.get_parser(buf)
    if parser then
      local tree = parser:parse()[1]
      if tree then node = tree:root():descendant_for_range(row, col, row, col) end
    end
  end
  if not node then return nil end

  -- 2. 一直向上找，直到找到真正的注释容器节点（跳过 comment_content 等）
  local comment_node = node
  while comment_node do
    if is_comment_container(comment_node:type()) then break end
    comment_node = comment_node:parent()
  end
  if not comment_node then return nil end

  -- 3. 收集注释容器节点的文本，以及它所有相邻的兄弟注释容器
  local parent = comment_node:parent()
  if not parent then return vim.treesitter.get_node_text(comment_node, buf) end

  local sr, _, er, _ = comment_node:range()
  local parts = { vim.treesitter.get_node_text(comment_node, buf) }
  local block_sr, block_er = sr, er

  -- 向上收集
  local prev = comment_node:prev_sibling()
  while prev and is_comment_container(prev:type()) do
    local psr, _, per, _ = prev:range()
    if per + 1 == block_sr then
      table.insert(parts, 1, vim.treesitter.get_node_text(prev, buf))
      block_sr = psr
      prev = prev:prev_sibling()
    else
      break
    end
  end

  -- 向下收集
  local next_sib = comment_node:next_sibling()
  while next_sib and is_comment_container(next_sib:type()) do
    local nsr, _, ner, _ = next_sib:range()
    if block_er + 1 == nsr then
      table.insert(parts, vim.treesitter.get_node_text(next_sib, buf))
      block_er = ner
      next_sib = next_sib:next_sibling()
    else
      break
    end
  end

  return table.concat(parts, '\n')
end

return M
