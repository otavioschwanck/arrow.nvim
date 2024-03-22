local M = {}

local persist = require('arrow.buffer_persist')

---@type Portal.QueryGenerator
local function generator(opts, settings)
  local Content = require('portal.content')
  local Iterator = require('portal.iterator')
  local Search = require('portal.search')

  local ok, _ = pcall(require, 'arrow')
  if not ok then
    return require('portal.log').error(
      "Unable to load 'arrow'. Please ensure that arrow is installed."
    )
  end

  local marks = require('arrow.buffer_persist').get_bookmarks_by()

  opts = vim.tbl_extend('force', {
    direction = 'forward',
    max_results = #settings.labels,
  }, opts or {})

  if settings.max_results then
    opts.max_results = math.min(opts.max_results, settings.max_results)
  end

    -- stylua: ignore
    local iter = Iterator:new(marks)
        :take(settings.lookback)

  if opts.start then
    iter = iter:start_at(opts.start)
  end
  if opts.direction == Search.direction.backward then
    iter = iter:reverse()
  end

  iter = iter:map(function(v, i)
    local buffer = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

    return Content:new({
      type = 'bookmarks',
      buffer = buffer,
      cursor = { row = v.line, col = 0 },
      callback = function(_)
        vim.api.nvim_win_set_cursor(win, { v.line, 0 })
      end,
      extra = {
        index = i,
      },
    })
  end)

  if settings.filter then
    iter = iter:filter(settings.filter)
  end
  if opts.filter then
    iter = iter:filter(opts.filter)
  end
  if not opts.slots then
    iter = iter:take(opts.max_results)
  end

  return {
    source = iter,
    slots = opts.slots,
  }
end

function M.openMenu()
  local Search = require('portal.search')

  local Settings = require('portal.settings')
  local settings = vim.tbl_deep_extend('force', Settings.as_table(), {})
  local query = function(opts)
    return generator(opts or {}, Settings)
  end

  local windows = require('portal').preview(query())

  local selected_window = Search.select(windows, settings.escape)
  if selected_window ~= nil then
    selected_window:select()
  end

  for _, window in ipairs(windows) do
    window:close()
  end
end

return M
