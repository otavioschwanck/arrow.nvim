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

return M
