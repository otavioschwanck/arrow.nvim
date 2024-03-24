local M = {}

local config = require("arrow.config")
local utils = require("arrow.utils")
local json = require("arrow.json")

M.local_bookmarks = {}

local function save_key(filename)
	return utils.normalize_path_to_filename(filename)
end

function M.cache_file_path(filename)
	local save_path = config.getState("save_path")()

	save_path = save_path:gsub("/$", "")

	if vim.fn.isdirectory(save_path) == 0 then
		vim.fn.mkdir(save_path, "p")
	end

	return save_path .. "/" .. save_key(filename)
end

function M.load_buffer_bookmarks(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local path = M.cache_file_path(vim.fn.expand("%:p"))

	if vim.fn.filereadable(path) == 0 then
		M.local_bookmarks[bufnr] = {}
	else
		local f = assert(io.open(path, "rb"))

		local content = f:read("*all")

		f:close()

		M.local_bookmarks[bufnr] = json.decode(content)
	end
end

function M.sync_buffer_bookmarks(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local buffer_file_name = vim.api.nvim_buf_get_name(bufnr)
	local path = M.cache_file_path(buffer_file_name)

	local path_dir = vim.fn.fnamemodify(path, ":h")

	if vim.fn.isdirectory(path_dir) == 0 then
		vim.fn.mkdir(path_dir, "p")
	end

	local file = io.open(path, "w")

	if file then
		file:write(json.encode(M.local_bookmarks[bufnr]))

		return true
	end

	return false
end

function M.is_saved(bufnr, bookmark)
	local saveds = M.get_bookmarks_by(bufnr)

	if saveds and #saveds > 0 then
		for _, saved in ipairs(saveds) do
			if utils.table_comp(saved, bookmark) then
				return true
			end
		end
	end

	return false
end

function M.remove(index, bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if M.local_bookmarks[bufnr] == nil then
		return
	end

	if M.local_bookmarks[bufnr][index] == nil then
		return
	end

	table.remove(M.local_bookmarks[bufnr], index)

	M.sync_buffer_bookmarks(bufnr)
end

function M.clear(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	M.local_bookmarks[bufnr] = {}

	M.sync_buffer_bookmarks(bufnr)
end

function M.save(bufnr, line_nr, col_nr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if not M.local_bookmarks[bufnr] then
		M.local_bookmarks[bufnr] = {}
	end

	local data = {
		line = line_nr,
		col = col_nr,
	}

	if not (M.is_saved(bufnr, data)) then
		table.insert(M.local_bookmarks[bufnr], data)

		M.sync_buffer_bookmarks(bufnr)

		print("SAVED")
	end
end

function M.get_bookmarks_by(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	return M.local_bookmarks[bufnr]
end

return M
