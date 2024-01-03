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
	-- Check if the filename is not already saved
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

return M
