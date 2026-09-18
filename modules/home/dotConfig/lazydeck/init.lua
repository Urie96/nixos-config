-- ── rbw secret 读取 ──────────────────────────────────────────────
-- shell 单引号转义
local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- 同步执行命令，返回 (exit_code, stdout)
-- stderr 丢弃到 /dev/null，防止 rbw 报错文本直接打印到 TUI 造成花屏
local function run(cmd)
  local handle = io.popen(cmd .. ' 2>/dev/null')
  if not handle then return nil end
  local out = handle:read '*a'
  local ok, why, code = handle:close()
  local exit_code = ok == true and 0 or (why == 'exit' and type(code) == 'number' and code) or 1
  return exit_code, out
end

local function get_secret(key)
  if run 'rbw unlocked' ~= 0 then
    deck.interactive({ 'rbw', 'unlock' }, { wait_confirm = function(exit_code) return exit_code ~= 0 end })
  end

  local _, value = run('rbw get ' .. shq(key))
  return value
end

deck.config {
  plugin_sort = 'most',
  plugins = {
    {
      'urie96/bookmarks.lazydeck',
      keys = {
        { 'ma', function() require('bookmarks').add() end, desc = 'add current page to bookmarks' },
      },
    },
    {
      'urie96/notification-history.lazydeck',
      lazy = false,
      keys = {
        { 'gn', function() deck.api.go_to { 'notification-history' } end, desc = 'notification history' },
      },
    },
    {
      'urie96/ai.lazydeck',
      config = function() require('ai').setup() end,
    },
    {
      'urie96/translate.lazydeck',
      config = function()
        require('translate').setup {
          target_language = 'Chinese',
          provider = 'deepseek',
          model = 'deepseek-v4-flash',
          max_input_tokens = 50000,
          cache_ttl = 30 * 24 * 3600,
        }
      end,
      keys = {
        { 'tt', function() require('translate').toggle() end, desc = 'toggle preview translation' },
      },
    },
    'urie96/rclone.lazydeck',
    {
      'urie96/audiobookshelf.lazydeck',
      config = function()
        require('audiobookshelf').setup {
          url = 'https://audiobook.lubui.com:8443',
          token = get_secret 'audiobookshelf-token',
          library_id = '1824413f-cbf0-41e4-8b88-c1aab95c7f40',
        }
      end,
    },
    {
      'urie96/github.lazydeck',
      config = function()
        require('github').setup {
          token = os.getenv 'GITHUB_TOKEN',
        }
      end,
    },
    {
      'urie96/netease-music.lazydeck',
      config = function()
        os.execute 'ssh -f -N -L 127.0.0.1:3000:127.0.0.1:3110 home.lubui.com &>/dev/null'
        require('netease-music').setup {
          base_url = 'http://localhost:3000',
          uid = '1622973455',
          cookie = 'MUSIC_U=',
        }
      end,
    },
    'urie96/adb.lazydeck',
    'urie96/hackernews.lazydeck',
    {
      'urie96/file.lazydeck',
      config = function()
        require('file').setup {
          root = os.getenv 'HOME',
        }
      end,
    },
    'urie96/aria2.lazydeck',
    {
      'urie96/freshrss.lazydeck',
      config = function()
        require('freshrss').setup {
          url = 'https://rss.lubui.com:8443/api/greader.php',
          login = 'urie',
          password = get_secret 'freshrss-password',
        }
      end,
    },
    'urie96/music.lazydeck',
    {
      'urie96/opensubsonic.lazydeck',
      config = function()
        require('opensubsonic').setup {
          url = 'https://music.lubui.com:8443',
          username = 'urie',
          password = get_secret 'navidrome-password',
        }
      end,
    },
    {
      dir = '/Users/bytedance/.local/share/lazydeck/plugins/apple-music.lazydeck',
      config = function()
        require('apple-music').setup {
          base_url = os.getenv 'APPLE_MUSIC_API_URL' or 'http://127.0.0.1:8899',
        }
      end,
    },
    'urie96/process.lazydeck',
    'urie96/quick-access-tools.lazydeck',
    'urie96/himalaya.lazydeck',
    {
      'urie96/notmuch.lazydeck',
      config = function()
        require('notmuch').setup {
          accounts = {
            {
              name = 'all',
              label = 'All',
              query = '*',
            },
            {
              name = 'qq',
              label = 'QQ',
              query = 'tag:account-qq',
              msmtp_account = 'qq',
            },
            {
              name = 'ustc',
              label = 'USTC',
              query = 'tag:account-ustc',
              msmtp_account = 'ustc',
            },
            {
              name = 'gmail',
              label = 'Gmail',
              query = 'tag:account-gmail',
              msmtp_account = 'gmail',
            },
          },
        }
      end,
    },
    'urie96/systemd.lazydeck',
    'urie96/launchd.lazydeck',
    'urie96/docker.lazydeck',
    {
      'urie96/sftp.lazydeck',
      config = function()
        require('sftp').setup {
          profiles = {
            home = {
              host = 'home.lubui.com',
              base_dir = '/home/urie',
            },
            kindle = {
              host = 'kindle.lan',
              base_dir = '/mnt/us',
            },
          },
        }
      end,
    },
    {
      'urie96/memos.lazydeck',
      config = function()
        require('memos').setup {
          token = os.getenv 'MEMOS_TOKEN',
          base_url = 'https://memos.lubui.com:8443',
        }
      end,
    },
  },
  keymap = {
    tab_new = '<tab>n',
    tab_close = '<tab>q',
    tab_next = '<tab><tab>',
    -- tab_prev = '<tab>',
  },
}
