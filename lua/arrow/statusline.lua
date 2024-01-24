local M = {}

local persist = require("arrow.persist")
local config = require("arrow.config")
local utils = require("arrow.utils")

local function show_right_index(index)
	return config.getState("index_keys"):sub(index, index)
end

function M.in_on_arrow_file()
	return persist.is_saved(utils.get_path_for("%"))
end

function M.text_for_statusline()
	local index = M.in_on_arrow_file()

	if index then
		return show_right_index(index)
	else
		return ""
	end
end

function M.text_for_statusline_with_icons()
	local index = M.in_on_arrow_file()

	if index then
		return "󱡁 " .. show_right_index(index)
	else
		return ""
	end
end

return M
