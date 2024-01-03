local M = {}

local config = require("arrow.config")
local persist = require("arrow.persist")

local fileNames = {}
local to_highlight = {}

local current_index = 0

local function getActionsMenu()
	local mappings = config.getState("mappings")

	if #vim.g.arrow_filenames == 0 then
		return {
			string.format("%s Save File", mappings.toggle),
		}
	end

	local already_saved = current_index > 0

	local text

	if already_saved == true then
		text = string.format("%s Remove Current", mappings.toggle)
	else
		text = string.format("%s Save Current File", mappings.toggle)
	end

	return {
		string.format(text, mappings.toggle),
		string.format("%s Edit Arrow File", mappings.edit),
		string.format("%s Clear All Items", mappings.clear_all_items),
		string.format("%s Delete mode", mappings.delete_mode),
		string.format("%s Open Vertical", mappings.open_vertical),
		string.format("%s Open Horizontal", mappings.open_horizontal),
		string.format("%s Quit", mappings.quit),
	}
end

local function format_file_names(file_names)
	local full_path_list = config.getState("full_path_list")
	local formatted_names = {}

	-- Table to store occurrences of file names (tail)
	local name_occurrences = {}

	for _, full_path in ipairs(file_names) do
		local tail = vim.fn.fnamemodify(full_path, ":t:r") -- Get the file name without extension

		if not name_occurrences[tail] then
			name_occurrences[tail] = { full_path }
		else
			table.insert(name_occurrences[tail], full_path)
		end
	end

	for _, full_path in ipairs(file_names) do
		local tail = vim.fn.fnamemodify(full_path, ":t:r")
		local tail_with_extension = vim.fn.fnamemodify(full_path, ":t")

		if #name_occurrences[tail] == 1 and not (vim.tbl_contains(full_path_list, tail)) then
			table.insert(formatted_names, tail_with_extension)
		else
			local path = vim.fn.fnamemodify(full_path, ":h")
			local display_path = path

			if vim.tbl_contains(full_path_list, tail) then
				display_path = vim.fn.fnamemodify(full_path, ":h")
			end

			table.insert(formatted_names, string.format("%s . %s", tail_with_extension, display_path))
		end
	end

	return formatted_names
end

-- Function to close the menu and open the selected file
local function closeMenu()
	local win = vim.fn.win_getid()
	vim.api.nvim_win_close(win, true)
end

local function get_file_icon(file_name)
	local webdevicons = require("nvim-web-devicons")
	local extension = vim.fn.fnamemodify(file_name, ":e")
	local icon, hl_group = webdevicons.get_icon(file_name, extension, { default = true })
	return icon, hl_group
end

local function renderBuffer(buffer)
	vim.api.nvim_buf_set_option(buffer, "modifiable", true)

	local icons = config.getState("show_icons")
	local buf = buffer or vim.api.nvim_get_current_buf()
	local lines = { "" }

	local formattedFleNames = format_file_names(fileNames)

	for i, fileName in ipairs(formattedFleNames) do
		local displayIndex = i

		if i > 9 then
			displayIndex = config.getState("after_9_keys"):sub(i - 9, i - 9)
		end

		if fileNames[i] == vim.b.filename then
			vim.api.nvim_buf_add_highlight(buf, -1, "ArrowDeleteMode", i + 3, 0, -1)

			current_index = i
		end

		vim.keymap.set("n", "" .. displayIndex, function()
			M.openFile(i)
		end, { buffer = buf, noremap = false, silent = true })

		if icons then
			local icon, hl_group = get_file_icon(fileNames[i])

			to_highlight[i] = hl_group

			fileName = icon .. " " .. fileName
		end

		table.insert(lines, string.format("   %s %s", displayIndex, fileName))
	end

	-- Add a separator
	if #vim.g.arrow_filenames == 0 then
		table.insert(lines, "   No files yet.")
	end

	table.insert(lines, "")

	local actionsMenu = getActionsMenu()

	-- Add actions to the menu
	for _, action in ipairs(actionsMenu) do
		table.insert(lines, "   " .. action)
	end

	table.insert(lines, "")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
end

-- Function to create the menu buffer with a list format
local function createMenuBuffer(filename)
	local buf = vim.api.nvim_create_buf(false, true)

	vim.b.filename = filename
	vim.b.arrow_current_mode = ""
	renderBuffer(buf)

	return buf
end

local function render_highlights(buffer)
	local actionsMenu = getActionsMenu()
	local mappings = config.getState("mappings")

	vim.api.nvim_buf_clear_namespace(buffer, -1, 0, -1)
	local menuBuf = buffer or vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowCurrentFile", current_index, 0, -1)

	for i, _ in ipairs(fileNames) do
		if vim.b.arrow_current_mode == "delete_mode" then
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowDeleteMode", i, 3, 4)
		else
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowFileIndex", i, 3, 4)
		end
	end

	if config.getState("show_icons") then
		for k, v in pairs(to_highlight) do
			vim.api.nvim_buf_add_highlight(menuBuf, -1, v, k, 7, 8)
		end
	end

	for i = #fileNames + 3, #fileNames + #actionsMenu + 3 do
		vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowAction", i - 1, 3, 4)
	end

	-- Find the line containing "d - Delete Mode"
	local deleteModeLine = -1
	local verticalModeLine = -1
	local horizontalModelLine = -1

	for i, action in ipairs(actionsMenu) do
		if action:find(mappings.delete_mode .. " Delete mode") then
			deleteModeLine = i - 1
		end

		if action:find(mappings.open_vertical .. " Open Vertical") then
			verticalModeLine = i - 1
		end

		if action:find(mappings.open_horizontal .. " Open Horizontal") then
			horizontalModelLine = i - 1
		end
	end

	if deleteModeLine >= 0 then
		if vim.b.arrow_current_mode == "delete_mode" then
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowDeleteMode", #fileNames + deleteModeLine + 2, 0, -1)
		end
	end

	if verticalModeLine >= 0 then
		if vim.b.arrow_current_mode == "vertical_mode" then
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowAction", #fileNames + verticalModeLine + 2, 0, -1)
		end
	end

	if horizontalModelLine >= 0 then
		if vim.b.arrow_current_mode == "horizontal_mode" then
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowAction", #fileNames + horizontalModelLine + 2, 0, -1)
		end
	end

	local pattern = " %. .-$"
	local line_number = 1

	while line_number <= #fileNames + 1 do
		local line_content = vim.api.nvim_buf_get_lines(menuBuf, line_number - 1, line_number, false)[1]

		local match_start, match_end = string.find(line_content, pattern)
		if match_start then
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowAction", line_number - 1, match_start - 1, match_end)
		end

		line_number = line_number + 1
	end
end

-- Function to open the selected file
function M.openFile(fileNumber)
	local fileName = fileNames[fileNumber]

	if vim.b.arrow_current_mode == "delete_mode" then
		persist.remove(fileName)

		fileNames = vim.g.arrow_filenames

		renderBuffer(vim.api.nvim_get_current_buf())
		render_highlights(vim.api.nvim_get_current_buf())
	else
		if not fileName then
			print("Invalid file number")
			return
		end

		local action

		if vim.b.arrow_current_mode == "" or not vim.b.arrow_current_mode then
			action = ":edit %s"
		elseif vim.b.arrow_current_mode == "vertical_mode" then
			action = ":vsplit %s"
		elseif vim.b.arrow_current_mode == "horizontal_mode" then
			action = ":split %s"
		end

		closeMenu()

		vim.cmd(string.format(action, fileName))
	end
end

function M.openMenu()
	to_highlight = {}
	fileNames = vim.g.arrow_filenames
	local filename = vim.fn.bufname("%")

	local parsedFileNames = format_file_names(fileNames)

	local max_width = 16
	for _, v in pairs(parsedFileNames) do
		if #v > max_width then
			max_width = #v
		end
	end

	local menuBuf = createMenuBuffer(filename)
	local height = #fileNames + 10
	local width = max_width + 10
	local mappings = config.getState("mappings")

	local row = math.ceil((vim.o.lines - height) / 2)
	local col = math.ceil((vim.o.columns - width) / 2)

	local is_empty = #vim.g.arrow_filenames == 0

	if is_empty then
		height = 5
		width = 18
	end

	local win = vim.api.nvim_open_win(menuBuf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "double",
	})

	vim.keymap.set("n", config.getState("leader_key"), closeMenu, { noremap = true, silent = true, buffer = menuBuf })
	vim.keymap.set("n", mappings.quit, closeMenu, { noremap = true, silent = true, buffer = menuBuf })
	vim.keymap.set("n", mappings.edit, function()
		closeMenu()
		persist.open_cache_file()
	end, { noremap = true, silent = true, buffer = menuBuf })
	vim.keymap.set("n", mappings.toggle, function()
		persist.toggle(filename)
		closeMenu()
	end, { noremap = true, silent = true, buffer = menuBuf })
	vim.keymap.set("n", mappings.clear_all_items, function()
		persist.clear()
		closeMenu()
	end, { noremap = true, silent = true, buffer = menuBuf })
	vim.keymap.set("n", "<Esc>", closeMenu, { noremap = true, silent = true, buffer = menuBuf })

	vim.keymap.set("n", mappings.delete_mode, function()
		if vim.b.arrow_current_mode == "delete_mode" then
			vim.b.arrow_current_mode = ""
		else
			vim.b.arrow_current_mode = "delete_mode"
		end

		renderBuffer(menuBuf)
		render_highlights(menuBuf)
	end, { noremap = true, silent = true, buffer = menuBuf })

	vim.keymap.set("n", mappings.open_vertical, function()
		if vim.b.arrow_current_mode == "vertical_mode" then
			vim.b.arrow_current_mode = ""
		else
			vim.b.arrow_current_mode = "vertical_mode"
		end

		renderBuffer(menuBuf)
		render_highlights(menuBuf)
	end, { noremap = true, silent = true, buffer = menuBuf })

	vim.keymap.set("n", mappings.open_horizontal, function()
		if vim.b.arrow_current_mode == "horizontal_mode" then
			vim.b.arrow_current_mode = ""
		else
			vim.b.arrow_current_mode = "horizontal_mode"
		end

		renderBuffer(menuBuf)
		render_highlights(menuBuf)
	end, { noremap = true, silent = true, buffer = menuBuf })

	local hl = vim.api.nvim_get_hl_by_name("Cursor", true)

	hl.blend = 100
	vim.api.nvim_set_hl(0, "Cursor", hl)
	vim.opt.guicursor:append("a:Cursor/lCursor")

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = 0,
		desc = "Disable Cursor",
		callback = function()
			local old_hl = vim.api.nvim_get_hl_by_name("Cursor", true)

			current_index = 0
			old_hl.blend = 0
			vim.api.nvim_set_hl(0, "Cursor", old_hl)
			vim.opt.guicursor:remove("a:Cursor/lCursor")
		end,
	})

	-- disable cursorline for this buffer
	vim.wo.cursorline = false

	vim.api.nvim_set_current_win(win)

	render_highlights(menuBuf)
end

-- Command to trigger the menu
return M
