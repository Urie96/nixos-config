---@param url string
local function kitty_open_url(url)
  local kitty_cmd_string = vim.json.encode {
    cmd = 'action',
    version = { 0, 26, 0 },
    payload = { action = 'open_url ' .. url },
    no_response = true,
  }
  local tty_string = '\x1bP@kitty-cmd' .. kitty_cmd_string .. '\x1b\\'
  vim.fn.chansend(vim.v.stderr, tty_string)
end

if vim.env.SSH_TTY then
  local orig_open = vim.ui.open
  vim.ui.open = function(path, opts)
    if opts ~= nil and #opts.cmd > 0 then orig_open(path, opts) end
    kitty_open_url(path)
  end
end

_G.Util = {}

---@param unix number
---@return string
function Util.relative_date_desc(unix)
  if not unix then return '-' end
  local secs = os.time() - unix
  if secs < 60 then
    return string.format('%d秒前', secs)
  elseif secs / 60 < 60 then
    return string.format('%d分钟前', secs / 60)
  elseif secs / 3600 < 24 then
    return string.format('%d小时前', secs / 3600)
  elseif secs / 3600 / 24 < 7 then
    return string.format('%d天前', secs / 3600 / 24)
  elseif secs / 3600 / 24 < 30 then
    return string.format('%d周前', secs / 3600 / 24 / 7)
  elseif secs / 3600 / 24 < 365 then
    return string.format('%d月前', secs / 3600 / 24 / 30)
  else
    return string.format('%d年前', secs / 3600 / 24 / 365)
  end
end
