local api = vim.api
local arrow_config = require("arrow.config")
local persist = require("arrow.buffer_persist")
local success, util = pcall(require, "satellite.util")
if not success then
	return
end

local HIGHLIGHT = "ArrowBookmarkSign"

local handler = {
	name = "arrow",
}

local config = arrow_config.getState("satellite_config")
if config.enable == false then
	return
end

function handler.setup(config0, update)
	config = vim.tbl_deep_extend("force", config, config0)
	handler.config = config
	local group = api.nvim_create_augroup("satellite_arrow_marks", {})
	api.nvim_create_autocmd("User", {
		group = group,
		pattern = "ArrowMarkUpdate",
		callback = vim.schedule_wrap(update),
	})
end

function handler.update(bufnr, winid)
	local ret = {}

	local marks = persist.get_bookmarks_by(bufnr)
	if marks then
		for i, mark in ipairs(marks) do
			local pos = util.row_to_barpos(winid, mark.line - 1)
			ret[#ret + 1] = {
				pos = pos,
				highlight = HIGHLIGHT,
				symbol = tostring(i),
			}
		end
	end

	return ret
end

require("satellite.handlers").register(handler)
