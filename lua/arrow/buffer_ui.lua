local M = {}

local preview_buffers = {}

local persist = require("arrow.buffer_persist")

function M.spawn_preview_window(buffer, index, bookmark)
	local lines_count = 4
	local height = math.ceil((vim.o.lines - 4) / 2)

	local row_count = (lines_count + 1)

	local window_config = {
		height = row_count,
		width = 120,
		row = height + (index - 1) * (row_count + 2),
		col = math.ceil((vim.o.columns - 120) / 2),
		style = "minimal",
		relative = "editor",
		border = "single",
	}

	local win = vim.api.nvim_open_win(buffer, true, window_config)

	vim.schedule(function()
		vim.api.nvim_win_set_option(win, "number", true)
		vim.api.nvim_win_set_cursor(win, { bookmark.line, 0 })
		vim.api.nvim_win_set_option(win, "scrolloff", 999)
	end)

	table.insert(preview_buffers, { buffer = buffer, win = win })
end

function M.spawn_action_windows() end

function M.openMenu()
	local bookmarks = persist.get_bookmarks_by()

	local bufnr = vim.api.nvim_get_current_buf()
	local opts_for_spawn = {}

	for index, bookmark in ipairs(bookmarks) do
		table.insert(opts_for_spawn, { bufnr, index, bookmark })
	end

	for _, opt in ipairs(opts_for_spawn) do
		M.spawn_preview_window(opt[1], opt[2], opt[3])
	end

	M.spawn_action_windows()
end

return M
