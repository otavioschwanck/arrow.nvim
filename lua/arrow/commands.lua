local ui = require("arrow.ui")
local buffer_ui = require("arrow.buffer_ui")
local buffer_persist = require("arrow.buffer_persist")

local M = {}

function M.cmd(cmd, opts)
	local command = M.commands[cmd]
	if command then
		command(opts)
	else
		M.error("unknown command: " .. cmd, { title = "Arrow" })
	end
end

M.commands = {
	open = function()
		ui.openMenu()
	end,
	toggle_current_line_for_buffer = function()
		local cur_buffer = vim.api.nvim_get_current_buf()
		local cur_line = vim.api.nvim_win_get_cursor(0)[1]
		local cur_col = vim.api.nvim_win_get_cursor(0)[2]

		buffer_ui.toggle_line(cur_buffer, cur_line, cur_col)

		buffer_persist.update()
		buffer_persist.sync_buffer_bookmarks()
		buffer_persist.clear_buffer_ext_marks(cur_buffer)
		buffer_persist.redraw_bookmarks(cur_buffer, buffer_persist.get_bookmarks_by(cur_buffer))
	end,
	inspectOpts = function(opts)
		print(vim.inspect(opts))
	end,
}

function M.setup()
	vim.api.nvim_create_user_command("Arrow", function(cmd)
		local opts = {}
		local prefix = M.parse(cmd.args)

		M.cmd(prefix, opts)
	end, {
		nargs = "?",
		desc = "Arrow",
		complete = function(_, line)
			local prefix = M.parse(line)
			return vim.tbl_filter(function(key)
				return key:find(prefix, 1, true) == 1
			end, vim.tbl_keys(M.commands))
		end,
	})
end

function M.parse(args)
	local parts = vim.split(vim.trim(args), "%s+")
	if parts[1]:find("Arrow") then
		table.remove(parts, 1)
	end
	if args:sub(-1) == " " then
		parts[#parts + 1] = ""
	end
	return table.remove(parts, 1) or "", parts
end

function M.error(msg, opts)
	opts = opts or {}
	opts.level = vim.log.levels.ERROR
	vim.notify(msg, opts)
end

return M
