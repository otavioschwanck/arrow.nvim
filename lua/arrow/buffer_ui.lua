local M = {}

local persist = require("arrow.buffer_persist")

function M.openMenu()
	-- TODO:Implement this

	local saveds = persist.get_bookmarks_by()

	for i, saved in ipairs(saveds) do
		require("notify")(vim.inspect(saved))
	end
end

return M
