local M = {}

local preview_buffers = {}

local persist = require("arrow.buffer_persist")
local config = require("arrow.config")

local lastRow = 0

local function getActionsMenu()
	local mappings = config.getState("mappings")

	local return_mappings = {
		string.format("  %s Save Current Line", mappings.toggle),
		string.format("  %s Delete Mode", mappings.delete_mode),
		string.format("  %s Clear All", mappings.clear_all_items),
		string.format("  %s Quit", mappings.quit),
	}

	return return_mappings
end

function M.spawn_preview_window(buffer, index, bookmark, bookmark_count)
	local lines_count = config.getState("per_buffer_config").lines

	local height = math.ceil((vim.o.lines - 4) / 2)

	local row = height + (index - 1) * (lines_count + 2) - (bookmark_count - 1) * lines_count

	lastRow = row

	local window_config = {
		height = lines_count,
		width = 120,
		row = row,
		col = math.ceil((vim.o.columns - 120) / 2),
		style = "minimal",
		relative = "editor",
		border = "single",
	}

	local win = vim.api.nvim_open_win(buffer, true, window_config)
	local displayIndex = config.getState("index_keys"):sub(index, index)

	vim.schedule(function()
		vim.api.nvim_win_set_cursor(win, { bookmark.line, 0 })
		vim.api.nvim_win_set_option(win, "scrolloff", 999)
		vim.api.nvim_win_set_config(win, { title = "" .. displayIndex })
		vim.api.nvim_win_set_option(win, "number", true)
	end)

	table.insert(preview_buffers, { buffer = buffer, win = win })
end

local function close_preview_windows()
	for _, buffer in ipairs(preview_buffers) do
		if vim.api.nvim_win_is_valid(buffer.win) then
			vim.api.nvim_win_close(buffer.win, true)
		end
	end
end

local function closeMenu(actions_buffer)
	lastRow = 0

	vim.api.nvim_buf_delete(actions_buffer, { force = true })

	close_preview_windows()

	preview_buffers = {}
end

local function go_to_bookmark(bookmark)
	vim.api.nvim_win_set_cursor(0, { bookmark.line, bookmark.col })

	-- centralize cursor
	vim.cmd("normal! zz")
end

function M.spawn_action_windows(call_buffer, bookmarks, line_nr, col_nr)
	local actions_buffer = vim.api.nvim_create_buf(false, true)
	local lines_count = config.getState("per_buffer_config").lines

	local window_config = {
		height = 5,
		width = 120 / 2,
		row = lastRow + lines_count + 2,
		col = math.ceil((vim.o.columns - 120) / 2),
		style = "minimal",
		relative = "editor",
		border = "single",
	}

	local win = vim.api.nvim_open_win(actions_buffer, true, window_config)
	local mappings = config.getState("mappings")

	local lines = getActionsMenu()

	local menuKeymapOpts = { noremap = true, silent = true, buffer = actions_buffer, nowait = true }

	vim.api.nvim_buf_set_option(actions_buffer, "modifiable", true)

	vim.api.nvim_buf_set_lines(actions_buffer, 0, -1, false, lines)

	vim.keymap.set("n", mappings.quit, function()
		closeMenu(actions_buffer)
	end, menuKeymapOpts)

	vim.keymap.set("n", config.getState("buffer_leader_key"), function()
		closeMenu(actions_buffer)
	end, menuKeymapOpts)

	vim.keymap.set("n", mappings.clear_all_items, function()
		persist.clear(call_buffer)
		closeMenu(actions_buffer)
	end, menuKeymapOpts)

	vim.keymap.set("n", mappings.clear_all_items, function()
		persist.clear(call_buffer)
		closeMenu(actions_buffer)
	end, menuKeymapOpts)

	vim.keymap.set("n", mappings.toggle, function()
		persist.save(call_buffer, line_nr, col_nr)
		closeMenu(actions_buffer)
	end, menuKeymapOpts)

	local indexes = config.getState("index_keys")

	for index, bookmark in ipairs(bookmarks) do
		vim.keymap.set("n", indexes:sub(index, index), function()
			closeMenu(actions_buffer)
			go_to_bookmark(bookmark)
		end, menuKeymapOpts)
	end

	local hl = vim.api.nvim_get_hl_by_name("Cursor", true)
	hl.blend = 100

	vim.opt.guicursor:append("a:Cursor/lCursor")
	vim.api.nvim_set_hl(0, "Cursor", hl)

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = 0,
		desc = "Disable Cursor",
		callback = function()
			vim.cmd("highlight clear Cursor")

			close_preview_windows()

			vim.schedule(function()
				local old_hl = hl
				old_hl.blend = 0
				vim.api.nvim_set_hl(0, "Cursor", old_hl)

				if vim.api.nvim_buf_is_valid(actions_buffer) then
					-- close buffer
					vim.api.nvim_buf_delete(actions_buffer, { force = true })
				end

				vim.opt.guicursor:remove("a:Cursor/lCursor")
			end)
		end,
	})
end

function M.openMenu()
	local bookmarks = persist.get_bookmarks_by()

	local bufnr = vim.api.nvim_get_current_buf()
	local line_nr = vim.api.nvim_win_get_cursor(0)[1]
	local col_nr = vim.api.nvim_win_get_cursor(0)[2]
	local opts_for_spawn = {}

	for index, bookmark in ipairs(bookmarks) do
		table.insert(opts_for_spawn, { bufnr, index, bookmark })
	end

	for _, opt in ipairs(opts_for_spawn) do
		M.spawn_preview_window(opt[1], opt[2], opt[3], #bookmarks)
	end

	M.spawn_action_windows(bufnr, bookmarks, line_nr, col_nr)
end

return M
