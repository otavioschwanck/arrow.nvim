local M = {}

-- Function to open a local bookmark by number (0-9)
-- @param number: integer between 0 and 9
-- @return boolean: true if bookmark was opened, false if invalid number or bookmark doesn't exist
function M.open_bookmark_by_number(number)
	-- Validate input
	if type(number) ~= "number" or number < 0 or number > 9 then
		vim.notify("Invalid bookmark number. Please use 0-9.", vim.log.levels.ERROR)
		return false
	end

	-- Get current bookmarks from global state
	local bookmarks = vim.g.arrow_filenames

	-- Convert 0-based input to 1-based index for Lua
	local index = number == 0 and 10 or number

	-- Check if bookmark exists
	if not bookmarks or #bookmarks < index then
		vim.notify(string.format("No bookmark found at position %d", number), vim.log.levels.WARN)
		return false
	end

	-- Get the filename for the bookmark
	local filename = bookmarks[index]
	if not filename then
		vim.notify(string.format("No bookmark found at position %d", number), vim.log.levels.WARN)
		return false
	end

	-- Get the save key and configuration
	local config = require("arrow.config")
	local global_bookmarks = config.getState("global_bookmarks")
	local save_key_name = config.getState("save_key_name")
	local save_key_cached = config.getState("save_key_cached")

	-- Determine how to open the file based on configuration
	if global_bookmarks == true or save_key_name == "cwd" or save_key_name == "git_root_bare" then
		vim.cmd(":edit " .. vim.fn.fnameescape(filename))
	else
		vim.cmd(":edit " .. vim.fn.fnameescape(save_key_cached .. "/" .. filename))
	end

	return true
end

return M
