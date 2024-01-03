local M = {}

local persist = require("arrow.persist")
local config = require("arrow.config")

local function show_right_index(index)
	if index < 10 then
		return index
	else
		return config.getState("after_9_keys"):sub(index - 9, index - 9)
	end
end

function M.is_on_harpoon_file()
	local filename = vim.fn.expand("%")

	return persist.is_saved(filename)
end

function M.text_for_statusline()
	local index = M.is_on_harpoon_file()

	if index then
		return show_right_index(index)
	else
		return ""
	end
end

function M.text_for_statusline_with_icons()
	local index = M.is_on_harpoon_file()

	if index then
		return "󱡁 " .. show_right_index(index)
	else
		return ""
	end
end

return M
