local M = {}

local config = require("arrow.config")
local persist = require("arrow.persist")
local utils = require("arrow.utils")
local git = require("arrow.git")

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

	local separate_save_and_remove = config.getState("separate_save_and_remove")

	local return_mappings = {
		string.format("%s Edit Arrow File", mappings.edit),
		string.format("%s Clear All Items", mappings.clear_all_items),
		string.format("%s Delete mode", mappings.delete_mode),
		string.format("%s Open Vertical", mappings.open_vertical),
		string.format("%s Open Horizontal", mappings.open_horizontal),
		string.format("%s Next Item", mappings.next_item),
		string.format("%s Prev Item", mappings.prev_item),
		string.format("%s Quit", mappings.quit),
	}

	if separate_save_and_remove then
		table.insert(return_mappings, 1, string.format("%s Remove Current File", mappings.remove))
		table.insert(return_mappings, 1, string.format("%s Save Current File", mappings.toggle))
	else
		if already_saved == true then
			table.insert(return_mappings, 1, string.format("%s Remove Current File", mappings.toggle))
		else
			table.insert(return_mappings, 1, string.format("%s Save Current File", mappings.toggle))
		end
	end

	return return_mappings
end

local function format_file_names(file_names)
	local full_path_list = config.getState("full_path_list")
	local formatted_names = {}

	-- Table to store occurrences of file names (tail)
	local name_occurrences = {}

	for _, full_path in ipairs(file_names) do
		local tail = vim.fn.fnamemodify(full_path, ":t:r") -- Get the file name without extension

		if vim.fn.isdirectory(full_path) == 1 then
			local parsed_path = full_path

			if parsed_path:sub(#parsed_path, #parsed_path) == "/" then
				parsed_path = parsed_path:sub(1, #parsed_path - 1)
			end

			local splitted_path = vim.split(parsed_path, "/")
			local folder_name = splitted_path[#splitted_path]

			if name_occurrences[folder_name] then
				table.insert(name_occurrences[folder_name], full_path)
			else
				name_occurrences[folder_name] = { full_path }
			end
		else
			if not name_occurrences[tail] then
				name_occurrences[tail] = { full_path }
			else
				table.insert(name_occurrences[tail], full_path)
			end
		end
	end

	for _, full_path in ipairs(file_names) do
		local tail = vim.fn.fnamemodify(full_path, ":t:r")
		local tail_with_extension = vim.fn.fnamemodify(full_path, ":t")

		if vim.fn.isdirectory(full_path) == 1 then
			if not (string.sub(full_path, #full_path, #full_path) == "/") then
				full_path = full_path .. "/"
			end

			local path = vim.fn.fnamemodify(full_path, ":h")

			local display_path = path

			local splitted_path = vim.split(display_path, "/")

			if #splitted_path > 1 then
				local folder_name = splitted_path[#splitted_path]

				local location = vim.fn.fnamemodify(full_path, ":h:h")

				if #name_occurrences[folder_name] > 1 or config.getState("always_show_path") then
					table.insert(formatted_names, string.format("%s . %s", folder_name .. "/", location))
				else
					table.insert(formatted_names, string.format("%s", folder_name .. "/"))
				end
			else
				if config.getState("always_show_path") then
					table.insert(formatted_names, full_path .. " . /")
				else
					table.insert(formatted_names, full_path)
				end
			end
		elseif
			not (config.getState("always_show_path"))
			and #name_occurrences[tail] == 1
			and not (vim.tbl_contains(full_path_list, tail))
		then
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
	if vim.fn.isdirectory(file_name) == 1 then
		return "", "Normal"
	end

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

		displayIndex = config.getState("index_keys"):sub(i, i)

		vim.api.nvim_buf_add_highlight(buf, -1, "ArrowDeleteMode", i + 3, 0, -1)

		local parsed_filename = fileNames[i]

		if fileNames[i]:sub(1, 2) == "./" then
			parsed_filename = fileNames[i]:sub(3)
		end

		if parsed_filename == vim.b.filename then
			current_index = i
		end

		vim.keymap.set("n", "" .. displayIndex, function()
			M.openFile(i)
		end, { noremap = true, silent = true, buffer = buf, nowait = true })

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
	if not (config.getState("hide_handbook")) then
		for _, action in ipairs(actionsMenu) do
			table.insert(lines, "   " .. action)
		end
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
			vim.api.nvim_buf_add_highlight(menuBuf, -1, v, k, 5, 8)
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
function M.openFile(fileNumber, previousFile)
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

		fileName = vim.fn.fnameescape(fileName)

		if vim.b.arrow_current_mode == "" or not vim.b.arrow_current_mode then
			action = config.getState("open_action")
		elseif vim.b.arrow_current_mode == "vertical_mode" then
			action = config.getState("vertical_action")
		elseif vim.b.arrow_current_mode == "horizontal_mode" then
			action = config.getState("horizontal_action")
		end

		closeMenu()
		action(config.getState("save_key_cached") .. "/" .. fileName, vim.b.filename)
	end
end

function M.getWindowConfig()
	local show_handbook = not (config.getState("hide_handbook"))
	local parsedFileNames = format_file_names(fileNames)
	local separate_save_and_remove = config.getState("separate_save_and_remove")

	local max_width = 0
	if show_handbook then
		max_width = 13
		if separate_save_and_remove then
			max_width = max_width + 2
		end
	end
	for _, v in pairs(parsedFileNames) do
		if #v > max_width then
			max_width = #v
		end
	end

	local width = max_width + 12
	local height = #fileNames + 2

	if show_handbook then
		height = height + 10
		if separate_save_and_remove then
			height = height + 1
		end
	end

	local current_config = {
		width = width,
		height = height,
		row = math.ceil((vim.o.lines - height) / 2),
		col = math.ceil((vim.o.columns - width) / 2),
	}

	local is_empty = #vim.g.arrow_filenames == 0

	if is_empty and show_handbook then
		current_config.height = 5
		current_config.width = 18
	elseif is_empty then
		current_config.height = 3
		current_config.width = 18
	end

	local res = vim.tbl_deep_extend("force", current_config, config.getState("window"))

	if res.width == "auto" then
		res.width = current_config.width
	end
	if res.height == "auto" then
		res.height = current_config.height
	end
	if res.row == "auto" then
		res.row = current_config.row
	end
	if res.col == "auto" then
		res.col = current_config.col
	end

	return res
end

function M.openMenu()
	git.refresh_git_branch()

	if vim.g.arrow_filenames == 0 then
		persist.load_cache_file()
	end

	to_highlight = {}
	fileNames = vim.g.arrow_filenames
	local filename

	if config.getState("global_bookmarks") == true then
		filename = vim.fn.expand("%:p")
	else
		filename = utils.get_current_buffer_path()
	end

	local menuBuf = createMenuBuffer(filename)

	local window_config = M.getWindowConfig()

	local win = vim.api.nvim_open_win(menuBuf, true, window_config)

	local mappings = config.getState("mappings")

	local separate_save_and_remove = config.getState("separate_save_and_remove")

	local menuKeymapOpts = { noremap = true, silent = true, buffer = menuBuf, nowait = true }

	vim.keymap.set("n", config.getState("leader_key"), closeMenu, menuKeymapOpts)
	vim.keymap.set("n", mappings.quit, closeMenu, menuKeymapOpts)
	vim.keymap.set("n", mappings.edit, function()
		closeMenu()
		persist.open_cache_file()
	end, menuKeymapOpts)

	if separate_save_and_remove then
		vim.keymap.set("n", mappings.toggle, function()
			filename = filename or utils.get_current_buffer_path()

			persist.save(filename)
			closeMenu()
		end, menuKeymapOpts)

		vim.keymap.set("n", mappings.remove, function()
			filename = filename or utils.get_current_buffer_path()

			persist.remove(filename)
			closeMenu()
		end, menuKeymapOpts)
	else
		vim.keymap.set("n", mappings.toggle, function()
			persist.toggle(filename)
			closeMenu()
		end, menuKeymapOpts)
	end

	vim.keymap.set("n", mappings.clear_all_items, function()
		persist.clear()
		closeMenu()
	end, menuKeymapOpts)

	vim.keymap.set("n", mappings.next_item, function()
		closeMenu()
		persist.next()
	end, menuKeymapOpts)

	vim.keymap.set("n", mappings.prev_item, function()
		closeMenu()
		persist.previous()
	end, menuKeymapOpts)

	vim.keymap.set("n", "<Esc>", closeMenu, menuKeymapOpts)

	vim.keymap.set("n", mappings.delete_mode, function()
		if vim.b.arrow_current_mode == "delete_mode" then
			vim.b.arrow_current_mode = ""
		else
			vim.b.arrow_current_mode = "delete_mode"
		end

		renderBuffer(menuBuf)
		render_highlights(menuBuf)
	end, menuKeymapOpts)

	vim.keymap.set("n", mappings.open_vertical, function()
		if vim.b.arrow_current_mode == "vertical_mode" then
			vim.b.arrow_current_mode = ""
		else
			vim.b.arrow_current_mode = "vertical_mode"
		end

		renderBuffer(menuBuf)
		render_highlights(menuBuf)
	end, menuKeymapOpts)

	vim.keymap.set("n", mappings.open_horizontal, function()
		if vim.b.arrow_current_mode == "horizontal_mode" then
			vim.b.arrow_current_mode = ""
		else
			vim.b.arrow_current_mode = "horizontal_mode"
		end

		renderBuffer(menuBuf)
		render_highlights(menuBuf)
	end, menuKeymapOpts)

	local hl = vim.api.nvim_get_hl_by_name("Cursor", true)
	hl.blend = 100

	vim.opt.guicursor:append("a:Cursor/lCursor")
	vim.api.nvim_set_hl(0, "Cursor", hl)

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = 0,
		desc = "Disable Cursor",
		callback = function()
			current_index = 0

			vim.cmd("highlight clear Cursor")

			vim.schedule(function()
				local old_hl = hl
				old_hl.blend = 0
				pcall(vim.api.nvim_set_hl, 0, "Cursor", old_hl)

				vim.opt.guicursor:remove("a:Cursor/lCursor")
			end)
		end,
	})

	-- disable cursorline for this buffer
	vim.wo.cursorline = false

	vim.api.nvim_set_current_win(win)

	render_highlights(menuBuf)
end

-- Command to trigger the menu
return M
