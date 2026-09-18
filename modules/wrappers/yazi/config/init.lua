require('session'):setup {
  sync_yanked = true,
}

function Linemode:mime() return ui.Line(self._file:mime() or '') end

local os_icon, os_icon_color = '', 'green'
local target = ya.target_os()
if target == 'linux' then
  local distro_icons = {
    arch = { ' ', '#1793D1' },
    centos = { ' ', '#932279' },
    debian = { ' ', '#D70A53' },
    manjaro = { ' ', '#35BF5C' },
    nixos = { ' ', '#5277C3' },
    ubuntu = { ' ', '#E95420' },
  }

  local id
  local f = io.open('/etc/os-release', 'r')
  if f then
    for line in f:lines() do
      id = line:match '^ID="?([^"%s]+)"?%s*$'
      if id then break end
    end
    f:close()
  end

  local distro = distro_icons[id] or { ' ', '#333333' }
  os_icon, os_icon_color = distro[1], distro[2]
elseif target == 'macos' then
  os_icon = '󰀵 '
  os_icon_color = '#11111b'
elseif target == 'android' then
  os_icon = ' '
  os_icon_color = '#A4C639'
elseif target == 'windows' then
  os_icon = ' '
  os_icon_color = '#0078d7'
end

local hostname = ' ' .. (os.getenv 'SSH_CONNECTION' and 'ssh://' or '') .. ya.host_name()

local is_root = ya.user_name() == 'root'

Header:children_add(function()
  if ya.target_family() ~= 'unix' and ya.target_os() ~= 'windows' then return ui.Line {} end
  if is_root then return ui.Span(ya.user_name() .. '@' .. ya.host_name() .. ':'):fg('red'):bold() end

  local crust, white, red, peach, yellow, green, sapphire, lavender =
    '#11111b', '#cdd6f4', '#f38ba8', '#fab387', '#f9e2af', '#a6e3a1', '#74c7ec', '#b4befe'
  return ui.Line {
    ui.Span(''):fg(white),
    ui.Span(os_icon):fg(os_icon_color):bg(white),
    ui.Span(''):fg(white):bg(peach),
    ui.Span(hostname):fg(crust):bg(peach):bold(),
    -- ui.Span(''):fg(red):bg(peach),
    -- ui.Span(' ' .. ya.user_name()):fg(crust):bg(peach),
    ui.Span(''):fg(peach):bg(yellow),
    ui.Span(''):fg(yellow):bg(green),
    ui.Span(''):fg(green):bg(sapphire),
    ui.Span(''):fg(sapphire):bg(lavender),
    ui.Span(' '):fg(lavender),
  }
end, 500, Header.LEFT)

-- bottom bar add owner:group
Status:children_add(function()
  local h = cx.active.current.hovered
  if h == nil or ya.target_family() ~= 'unix' then return ui.Line {} end

  return ui.Line {
    ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)):fg 'magenta',
    ui.Span ':',
    ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)):fg 'magenta',
    ui.Span ' ',
  }
end, 500, Status.RIGHT)

-- plugin setup
require('git'):setup { order = 1500 }

require('mime-ext.local'):setup {
  with_files = {
    makefile = 'text/makefile',
    ['uv.lock'] = 'text/toml',
    ['go.mod'] = 'text/plain',
    ['go.sum'] = 'text/plain',
    ['.clangd'] = 'text/yaml',
    justfile = 'text/x-makefile',
  },
  with_exts = {
    mk = 'text/makefile',
    raf = 'image/fuji-raf',
    http = 'text/http',
    jsonl = 'application/json',
    thrift = 'text/c',
    sql = 'text/plain',
  },
  fallback_file1 = true,
}

require('full-border'):setup { type = ui.Border.ROUNDED }

-- require('yamb'):setup {}

-- Folder-specific sort rules (replaces folder-rules plugin)
ps.sub('ind-sort', function(opt)
  local cwd = cx.active.current.cwd
  if cwd:ends_with 'Downloads' then
    opt.by, opt.reverse, opt.dir_first = 'mtime', true, false
  else
    opt.by, opt.reverse, opt.dir_first = 'mtime', true, true
  end
  return opt
end)

-- Custom app title (replaces deprecated title_format in yazi.toml)
ps.sub('ind-app-title', function(args)
  local cwd = tostring(cx.active.current.cwd)
  local home = os.getenv 'HOME'
  if home then cwd = cwd:gsub('^' .. home, '~') end
  args.value = 'YA:' .. cwd
  return args
end)
