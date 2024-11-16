local M = {}

M.global_bookmarks = {}

function M.remove(index)
	-- Debug prints
	print("Attempting to remove bookmark at index:", index)
	print("Current bookmarks:", vim.inspect(M.global_bookmarks))

	if M.global_bookmarks[index] then
		local removed = table.remove(M.global_bookmarks, index)
		print("Removed bookmark:", removed)

		-- Cache the updated bookmarks
		M.cache_file()

		-- Verify removal
		print("Bookmarks after removal:", vim.inspect(M.global_bookmarks))
		return true
	end

	print("No bookmark found at index:", index)
	return false
end

function M.is_saved(filename)
	-- Convert to absolute path for comparison
	local abs_path = vim.fn.fnamemodify(filename, ":p")

	for i, name in ipairs(M.global_bookmarks) do
		if name == abs_path then
			return i
		end
	end
	return nil
end

function M.save(filename)
	-- Force absolute path conversion
	local abs_path = vim.fn.fnamemodify(filename, ":p")

	if not M.is_saved(abs_path) then
		table.insert(M.global_bookmarks, abs_path)
		M.cache_file()
	end
end

function M.cache_file()
	local save_path = require("arrow.config").getState("save_path")()
	save_path = save_path:gsub("/$", "")
	if vim.fn.isdirectory(save_path) == 0 then
		vim.fn.mkdir(save_path, "p")
	end

	local cache_path = save_path .. "/global_bookmarks"

	-- Always write the file, even if empty
	local lines = {}
	if #M.global_bookmarks > 0 then
		local content = table.concat(M.global_bookmarks, "\n")
		lines = vim.split(content, "\n")
	end

	vim.fn.writefile(lines, cache_path)

	-- Force reload to ensure state is consistent
	M.load_cache_file()
end

function M.load_cache_file()
	local save_path = require("arrow.config").getState("save_path")()
	save_path = save_path:gsub("/$", "")
	local cache_path = save_path .. "/global_bookmarks"

	if vim.fn.filereadable(cache_path) == 0 then
		M.global_bookmarks = {}
		return
	end

	local success, data = pcall(vim.fn.readfile, cache_path)
	if success and data then
		M.global_bookmarks = vim.tbl_filter(function(line)
			return line and #line > 0
		end, data)
	else
		M.global_bookmarks = {}
	end
end

function M.open_cache_file()
	local save_path = require("arrow.config").getState("save_path")()
	save_path = save_path:gsub("/$", "")

	if vim.fn.isdirectory(save_path) == 0 then
		vim.fn.mkdir(save_path, "p")
	end

	local cache_path = save_path .. "/global_bookmarks"
	local content = {}

	if vim.fn.filereadable(cache_path) == 1 then
		content = vim.fn.readfile(cache_path)
	end

	local bufnr = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

	local width = math.min(80, vim.fn.winwidth(0) - 4)
	local height = math.min(20, #content + 2)

	local row = math.ceil((vim.o.lines - height) / 2)
	local col = math.ceil((vim.o.columns - width) / 2)

	local opts = {
		style = "minimal",
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		focusable = true,
		border = "single",
	}

	local winid = vim.api.nvim_open_win(bufnr, true, opts)

	-- Set up keymaps
	local close_buffer = ":lua vim.api.nvim_win_close(" .. winid .. ", {force = true})<CR>"
	vim.api.nvim_buf_set_keymap(bufnr, "n", "q", close_buffer, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", close_buffer, { noremap = true, silent = true })
	vim.keymap.set(
		"n",
		require("arrow.config").getState("leader_key"),
		close_buffer,
		{ noremap = true, silent = true, buffer = bufnr }
	)

	-- Save on buffer leave
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = bufnr,
		desc = "save global bookmarks buffer on leave",
		callback = function()
			local updated_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			vim.fn.writefile(updated_content, cache_path)
			M.load_cache_file()
		end,
	})

	vim.cmd("setlocal nu")

	return bufnr, winid
end

return M
