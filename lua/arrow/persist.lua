local M = {}

local config = require("arrow.config")

local function normalize_path_to_filename(path)
	return path:gsub("/", "_")
end

local function cache_file_path()
	return vim.fn.stdpath("cache") .. normalize_path_to_filename(config.getState("save_key")())
end

vim.g.arrow_filenames = {}

function M.save(filename)
	if not M.is_saved(filename) then
		local new_table = vim.g.arrow_filenames
		table.insert(new_table, filename)
		vim.g.arrow_filenames = new_table

		M.cache_file()
		M.load_cache_file()
	end
end

function M.remove(filename)
	local index = M.is_saved(filename)
	if index then
		local new_table = vim.g.arrow_filenames
		table.remove(new_table, index)
		vim.g.arrow_filenames = new_table

		M.cache_file()
		M.load_cache_file()
	end
end

function M.toggle(filename)
	filename = filename or vim.fn.bufname("%")

	local index = M.is_saved(filename)
	if index then
		M.remove(filename)
	else
		M.save(filename)
	end
end

function M.clear()
	vim.g.arrow_filenames = {}
	M.cache_file()
	M.load_cache_file()
end

function M.is_saved(filename)
	for i, name in ipairs(vim.g.arrow_filenames) do
		if name == filename then
			return i
		end
	end
	return nil
end

function M.load_cache_file()
	local success, data = pcall(vim.fn.readfile, cache_file_path())
	if success then
		vim.g.arrow_filenames = data
	else
		vim.g.arrow_filenames = {}
	end
end

function M.cache_file()
	local content = vim.fn.join(vim.g.arrow_filenames, "\n")
	local lines = vim.fn.split(content, "\n")
	vim.fn.writefile(lines, cache_file_path())
end

function M.go_to(index)
	local filename = vim.g.arrow_filenames[index]

	if filename then
		vim.cmd(":edit " .. filename)
	end
end

function M.next()
	local current_index = M.is_saved(vim.fn.bufname("%"))
	local next_index

	if current_index and current_index < #vim.g.arrow_filenames then
		next_index = current_index + 1
	else
		next_index = 1
	end

	M.go_to(next_index)
end

function M.previous()
	local current_index = M.is_saved(vim.fn.bufname("%"))
	local previous_index

	if current_index and current_index == 1 then
		previous_index = #vim.g.arrow_filenames
	elseif current_index then
		previous_index = current_index - 1
	else
		previous_index = #vim.g.arrow_filenames
	end

	M.go_to(previous_index)
end

function M.open_cache_file()
	local cache_path = cache_file_path()
	local cache_content = vim.fn.readfile(cache_path)

	local bufnr = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, cache_content)

	local width = math.min(80, vim.fn.winwidth(0) - 4)
	local height = math.min(20, #cache_content + 2)

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

	local close_buffer = ":lua vim.api.nvim_win_close(" .. winid .. ", {force = true})<CR>"
	vim.api.nvim_buf_set_keymap(bufnr, "n", "q", close_buffer, { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", close_buffer, { noremap = true, silent = true })
	vim.keymap.set(
		"n",
		config.getState("leader_key"),
		function() end,
		{ noremap = true, silent = true, buffer = bufnr }
	)

	vim.keymap.set("n", "<CR>", function()
		local line = vim.api.nvim_get_current_line()

		vim.api.nvim_win_close(winid, { force = true })
		vim.cmd(":edit " .. line)
	end, { noremap = true, silent = true, buffer = bufnr })

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = bufnr,
		desc = "save cache buffer on leave",
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
