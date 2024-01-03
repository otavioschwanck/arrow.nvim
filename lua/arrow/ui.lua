local M = {}

local config = require("arrow.config")
local persist = require("arrow.persist")

local fileNames = {}

local current_index = 0

local after_text = "zxcvbnmadfghjkl"

local function getActionsMenu()
	local mappings = config.getState("mappings")

	local already_saved = current_index > 0

	local text

	if already_saved == true then
		text = string.format("%s Remove Current", mappings.toggle)
	else
		text = string.format("%s Save Current File", mappings.toggle)
	end

	return {
		string.format(text, mappings.toggle),
		string.format("%s Edit File", mappings.edit),
		string.format("%s Clear All Items", mappings.clear_all_items),
		string.format("%s Delete mode", mappings.delete_mode),
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

local function renderBuffer(buffer)
	vim.api.nvim_buf_set_option(buffer, "modifiable", true)

	local buf = buffer or vim.api.nvim_get_current_buf()
	local lines = { "" }

	local formattedFleNames = format_file_names(fileNames)

	for i, fileName in ipairs(formattedFleNames) do
		local displayIndex = i

		if i > 9 then
			displayIndex = after_text:sub(i - 9, i - 9)
		end

		if fileNames[i] == vim.b.filename then
			vim.api.nvim_buf_add_highlight(buf, -1, "@error", i + 3, 0, -1)

			current_index = i
		end

		vim.keymap.set("n", "" .. displayIndex, function()
			M.openFile(i)
		end, { buffer = buf, noremap = false, silent = true })

		table.insert(lines, string.format("   %s %s", displayIndex, fileName))
	end

	-- Add a separator
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

	vim.b.delete_mode = false
	renderBuffer(buf)

	return buf
end

local function render_highlights(buffer)
	local actionsMenu = getActionsMenu()

	vim.api.nvim_buf_clear_namespace(buffer, -1, 0, -1)
	local menuBuf = buffer or vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_add_highlight(menuBuf, -1, "@character.special", current_index, 0, -1)

	for i, _ in ipairs(fileNames) do
		if vim.b.delete_mode then
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "@error", i, 0, 4)
		else
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "@attribute", i, 0, 4)
		end
	end

	for i = #fileNames + 2, #fileNames + #actionsMenu + 2 do
		vim.api.nvim_buf_add_highlight(menuBuf, -1, "@character", i - 1, 0, 4)
	end

	-- Find the line containing "d - Delete Mode"
	local deleteModeLine = -1
	for i, action in ipairs(actionsMenu) do
		if action:find("d Delete mode") then
			deleteModeLine = i - 1
			break
		end
	end

	if deleteModeLine >= 0 then
		if vim.b.delete_mode then
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "@error", #fileNames + deleteModeLine + 2, 0, -1)
		end
	end

	local pattern = " %. .-$"
	local line_number = 1

	while line_number <= #fileNames do
		local line_content = vim.api.nvim_buf_get_lines(menuBuf, line_number - 1, line_number, false)[1]

		local match_start, match_end = string.find(line_content, pattern)
		if match_start then
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "@character", line_number - 1, match_start - 1, match_end)
		end

		line_number = line_number + 1
	end
end

-- Function to open the selected file
function M.openFile(fileNumber)
	local fileName = fileNames[fileNumber]

	if vim.b.delete_mode then
		persist.remove(fileName)

		fileNames = vim.g.arrow_filenames

		renderBuffer(vim.api.nvim_get_current_buf())
		render_highlights(vim.api.nvim_get_current_buf())
	else
		if not fileName then
			print("Invalid file number")
			return
		end

		closeMenu()

		vim.cmd(string.format(":edit %s", fileName))
	end
end

function M.openMenu()
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
	local height = #fileNames + 5 + 3
	local width = max_width + 8
	local mappings = config.getState("mappings")

	local row = math.ceil((vim.o.lines - height) / 2)
	local col = math.ceil((vim.o.columns - width) / 2)

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
	vim.keymap.set("n", mappings.toggle, function()
		persist.toggle(filename)
		closeMenu()
	end, { noremap = true, silent = true, buffer = menuBuf })
	vim.keymap.set("n", mappings.clear_all_items, function()
		persist.clear()
		closeMenu()
	end)
	vim.keymap.set("n", "<Esc>", closeMenu, { noremap = true, silent = true, buffer = menuBuf })

	vim.keymap.set("n", mappings.delete_mode, function()
		vim.b.delete_mode = not vim.b.delete_mode
		renderBuffer(menuBuf)
		render_highlights(menuBuf)
	end, { noremap = true, silent = true, buffer = menuBuf })

	local hl = vim.api.nvim_get_hl_by_name("Cursor", true)

	hl.blend = 100
	vim.api.nvim_set_hl(0, "Cursor", hl)
	vim.opt.guicursor:append("a:Cursor/lCursor")

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = 0,
		desc = "show cursor after alpha",
		callback = function()
			local old_hl = vim.api.nvim_get_hl_by_name("Cursor", true)

			current_index = 0
			old_hl.blend = 0
			vim.api.nvim_set_hl(0, "Cursor", old_hl)
			vim.opt.guicursor:remove("a:Cursor/lCursor")
		end,
	})

	vim.api.nvim_set_current_win(win)

	render_highlights(menuBuf)
end

-- Command to trigger the menu
return M
