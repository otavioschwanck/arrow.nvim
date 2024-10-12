local M = {}

local get_icon_from_web_dev_icons = function(file_name)
	local webdevicons = require("nvim-web-devicons")
	local extension = vim.fn.fnamemodify(file_name, ":e")
	local icon, hl_group = webdevicons.get_icon(file_name, extension, { default = true })

	return icon, hl_group
end

local get_icon_from_mini = function(file_name)
	local icons = require("mini.icons")
	return icons.get("extension", file_name)
end

--- Gets file icon from either `nvim-web-devicons` or `mini.icons`.
--- @param file_name string
M.get_file_icon = function(file_name)
	if vim.fn.isdirectory(file_name) == 1 then
		return "", "Normal"
	end

	local use_web_dev_icons = pcall(require, "nvim-web-devicons")
	local use_mini_icons = pcall(require, "mini.icons")

	if not (use_web_dev_icons or use_mini_icons) then
		error("No icon provider found", vim.log.levels.ERROR)
	end

	if use_web_dev_icons then
		return get_icon_from_web_dev_icons(file_name)
	end

	return get_icon_from_mini(file_name)
end

return M
