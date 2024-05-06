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
local have_setup = false

if config.enable == false then
	return
end

function handler.setup(user_config, update)
	config = vim.tbl_deep_extend("force", config, user_config)
	handler.config = config
	local group = api.nvim_create_augroup("satellite_arrow_marks", {})
	api.nvim_create_autocmd("User", {
		group = group,
		pattern = "ArrowMarkUpdate",
		callback = vim.schedule_wrap(update),
	})
	have_setup = true
end

function handler.update(bufnr, winid)
	if not have_setup then
		handler.config = config
		local group = api.nvim_create_augroup("satellite_arrow_marks", {})
		api.nvim_create_autocmd("User", {
			group = group,
			pattern = "ArrowMarkUpdate",
			callback = vim.schedule_wrap(require("satellite.view").refresh_bars),
		})
		have_setup = true
	end
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
