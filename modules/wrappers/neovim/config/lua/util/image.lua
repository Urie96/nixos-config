local M = {}

local hover

local function hover_close()
  if hover then
    hover.win:close()
    hover.img:close()
    hover = nil
  end
end

local function float_show_image(src)
  if not src then return M.hover_close() end

  if hover and hover.img.img.src ~= src then
    hover_close()
  elseif hover then
    hover.img:update()
    return
  end

  local win = Snacks.win {
    max_width = 80,
    max_height = 40,
    position = 'float',
    backdrop = false,
    enter = false,
    show = false,
  }
  win:scratch()

  local updated = false
  local o = Snacks.config.merge({}, Snacks.image.config.doc, {
    on_update_pre = function()
      if hover and not updated then
        updated = true
        local loc = hover.img:state().loc
        win.opts.width = loc.width
        win.opts.height = loc.height
        win:show()
      end
    end,
    inline = false,
  })

  hover = {
    win = win,
    img = Snacks.image.placement.new(win.buf, src, o),
  }

  vim.api.nvim_create_autocmd({ 'BufWritePost', 'CursorMoved', 'ModeChanged', 'BufLeave' }, {
    group = vim.api.nvim_create_augroup('clear_hover_image', { clear = true }),
    once = true,
    callback = hover_close,
  })
end

function M.show_hover_image()
  local uri = vim.fn.expand '<cfile>'
  float_show_image(uri)
end

return M
