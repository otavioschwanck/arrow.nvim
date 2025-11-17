local M = {}

local config = require("arrow.config")
local persist = require("arrow.persist")
local utils = require("arrow.utils")
local git = require("arrow.git")
local icons = require("arrow.integration.icons")

local namespace = vim.api.nvim_create_namespace("arrow_files")
local fileNames = {}
local to_highlight = {}

local current_index = 0
local actionMenuIndent = 3

---@return {key: string, text: string}[]
local function getActionsMenu()
	local mappings = config.getState("mappings")
	local bookmark_type = config.getState("current_bookmark_type")

	local bookmark_list = bookmark_type == "dir" and vim.g.arrow_dir_bookmarks or vim.g.arrow_filenames
	local remove_text = bookmark_type == "dir" and "Remove Current Folder" or "Remove Current File"
	local save_text = bookmark_type == "dir" and "Save Current Folder" or "Save Current File"

	if #bookmark_list == 0 then
		return {
			{ key = mappings.toggle, text = string.format("%s %s", mappings.toggle, save_text) },
		}
	end

	local already_saved = current_index > 0

	local separate_save_and_remove = config.getState("separate_save_and_remove")

	local return_mappings = {
		{ key = mappings.edit, text = string.format("%s Edit Arrow File", mappings.edit) },
		{ key = mappings.clear_all_items, text = string.format("%s Clear All Items", mappings.clear_all_items) },
		{ key = mappings.delete_mode, text = string.format("%s Delete Mode", mappings.delete_mode) },
		-- { key = mappings.toggle_bookmark_type, text = string.format("%s Switch Mode", mappings.toggle_bookmark_type) },
		{ key = mappings.next_item, text = string.format("%s Next Item", mappings.next_item) },
		{ key = mappings.prev_item, text = string.format("%s Prev Item", mappings.prev_item) },
		{ key = mappings.quit, text = string.format("%s Quit", mappings.quit) },
	}

	-- Add split options only for file bookmarks
	if bookmark_type ~= "dir" then
		table.insert(
			return_mappings,
			4,
			{ key = mappings.open_vertical, text = string.format("%s Open Vertical", mappings.open_vertical) }
		)
		table.insert(
			return_mappings,
			5,
			{ key = mappings.open_horizontal, text = string.format("%s Open Horizontal", mappings.open_horizontal) }
		)
	end

	if separate_save_and_remove then
		table.insert(
			return_mappings,
			1,
			{ key = mappings.remove, text = string.format("%s %s", mappings.remove, remove_text) }
		)
		table.insert(
			return_mappings,
			1,
			{ key = mappings.toggle, text = string.format("%s %s", mappings.toggle, save_text) }
		)
	else
		if already_saved == true then
			table.insert(
				return_mappings,
				1,
				{ key = mappings.toggle, text = string.format("%s %s", mappings.toggle, remove_text) }
			)
		else
			table.insert(
				return_mappings,
				1,
				{ key = mappings.toggle, text = string.format("%s %s", mappings.toggle, save_text) }
			)
		end
	end

	return return_mappings
end

local function format_file_names(file_names)
	local full_path_list = config.getState("full_path_list")
	local dir_full_path_list = config.getState("dir_full_path_list")
	local formatted_names = {}

	-- Table to store occurrences of file names (tail)
	local name_occurrences = {}

	for _, full_path in ipairs(file_names) do
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
			local tail = vim.fn.fnamemodify(full_path, ":t:r") -- Get the file name without extension
			if not name_occurrences[tail] then
				name_occurrences[tail] = { full_path }
			else
				table.insert(name_occurrences[tail], full_path)
			end
		end
	end

	-- print(vim.inspect(name_occurrences))
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

				if
					#name_occurrences[folder_name] > 1
					or config.getState("always_show_path")
					or vim.tbl_contains(dir_full_path_list, folder_name)
				then
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

-- function to refresh the menu window config on switch
local function refreshMenu()
	local win = vim.fn.win_getid()
	local window_config = M.getWindowConfig()
	vim.api.nvim_win_set_config(win, window_config)
end

local function renderBuffer(buffer)
	vim.api.nvim_set_option_value("modifiable", true, { buf = buffer })

	local show_icons = config.getState("show_icons")
	local buf = buffer or vim.api.nvim_get_current_buf()
	local lines = { "" }

	local bookmark_type = config.getState("current_bookmark_type")
	local bookmark_list = bookmark_type == "dir" and vim.g.arrow_dir_bookmarks or vim.g.arrow_filenames
	fileNames = bookmark_list

	local formattedFleNames = format_file_names(fileNames)

	to_highlight = {}
	current_index = 0

	for i, fileName in ipairs(formattedFleNames) do
		local displayIndex = i

		displayIndex = config.getState("index_keys"):sub(i, i)

		-- vim.api.nvim_buf_add_highlight(buf, -1, "ArrowDeleteMode", i + 3, 0, -1)

		local parsed_filename = fileNames[i]

		if fileNames[i] and fileNames[i]:sub(1, 2) == "./" then
			parsed_filename = fileNames[i]:sub(3)
		end

		if parsed_filename == vim.b[buf].filename then
			current_index = i
		end

		vim.keymap.set("n", "" .. displayIndex, function()
			M.openFile(i)
		end, { noremap = true, silent = true, buffer = buf, nowait = true })

		if show_icons then
			local icon, hl_group = icons.get_file_icon(fileNames[i])

			to_highlight[i] = hl_group

			fileName = icon .. " " .. fileName
		end

		table.insert(lines, string.format("   %s %s", displayIndex, fileName))
	end

	-- Add a separator
	local empty_text = bookmark_type == "dir" and "   No directories yet." or "   No files yet."
	if #bookmark_list == 0 then
		table.insert(lines, empty_text)
	end

	table.insert(lines, "")

	local actionsMenu = getActionsMenu()

	-- Add actions to the menu
	if not (config.getState("hide_handbook")) then
		for _, action in ipairs(actionsMenu) do
			table.insert(lines, string.rep(" ", actionMenuIndent) .. action.text)
		end
	end

	table.insert(lines, "")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
end

-- Function to create the menu buffer with a list format
local function createMenuBuffer(filename)
	local buf = vim.api.nvim_create_buf(false, true)

	vim.b[buf].filename = filename
	vim.b[buf].arrow_current_mode = ""
	renderBuffer(buf)

	return buf
end

local function render_highlights(buffer)
	local actionsMenu = getActionsMenu()
	local mappings = config.getState("mappings")

	vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
	local menuBuf = buffer or vim.api.nvim_get_current_buf()

	-- vim.api.nvim_set_hl(0, "FloatBorder", borderHighlight)

	vim.api.nvim_buf_set_extmark(menuBuf, namespace, current_index, 0, {
		hl_eol = true,
		hl_group = "ArrowCurrentFile",
	})

	---------------------------------------------
	-- setting highlights for file/dir indexes --
	---------------------------------------------
	for i, _ in ipairs(fileNames) do
		local line = vim.api.nvim_buf_get_lines(menuBuf, i, i + 1, false)[1]
		if line and #line >= 4 then
			if vim.b.arrow_current_mode == "delete_mode" then
				vim.api.nvim_buf_set_extmark(menuBuf, namespace, i, 3, {
					end_col = 4,
					hl_group = "ArrowDeleteMode",
				})
			elseif vim.b.arrow_current_mode == "vertical_mode" or vim.b.arrow_current_mode == "horizontal_mode" then
				vim.api.nvim_buf_set_extmark(menuBuf, namespace, i, 3, {
					end_col = 4,
					hl_group = "ArrowSplitMode",
				})
			else
				vim.api.nvim_buf_set_extmark(menuBuf, namespace, i, 3, {
					end_col = 4,
					hl_group = "ArrowFileIndex",
				})
			end
		end
	end

	----------------------------------
	-- setting highlights for icons --
	----------------------------------
	if config.getState("show_icons") then
		for k, v in pairs(to_highlight) do
			local line = vim.api.nvim_buf_get_lines(menuBuf, k, k + 1, false)[1]
			if line and #line >= 8 then
				vim.api.nvim_buf_set_extmark(menuBuf, namespace, k, 5, {
					end_col = 8,
					hl_group = v,
				})
			end
		end
	end

	----------------------------------------------------
	-- setting highlights for action menu description --
	----------------------------------------------------
	-- compensate for the empty file/dir text line when there is no files
	-- default 3 spacings + filenames count
	local topSpacing = #fileNames == 0 and 4 or 3
	local lineCountTilActions = #fileNames + topSpacing
	for i = lineCountTilActions, #actionsMenu + lineCountTilActions do
		local actionMenuIndex = i - lineCountTilActions + 1
		if actionMenuIndex <= #actionsMenu then
			local action = actionsMenu[actionMenuIndex]
			vim.api.nvim_buf_set_extmark(menuBuf, namespace, i - 1, actionMenuIndent, {
				end_col = actionMenuIndent + #action.key,
				hl_group = "ArrowAction",
			})

			local nextStartCol = actionMenuIndent + #action.key
			if vim.b.arrow_current_mode == "delete_mode" and action.key == mappings.delete_mode then
				vim.api.nvim_buf_set_extmark(menuBuf, namespace, i - 1, nextStartCol, {
					end_col = nextStartCol + #action.text - 1,
					hl_group = "ArrowDeleteMode",
				})
			end

			if vim.b.arrow_current_mode == "vertical_mode" and action.key == mappings.open_vertical then
				vim.api.nvim_buf_set_extmark(menuBuf, namespace, i - 1, nextStartCol, {
					end_col = nextStartCol + #action.text - 1,
					hl_group = "ArrowSplitMode",
				})
			end

			if vim.b.arrow_current_mode == "horizontal_mode" and action.key == mappings.open_horizontal then
				vim.api.nvim_buf_set_extmark(menuBuf, namespace, i - 1, nextStartCol, {
					end_col = nextStartCol + #action.text - 1,
					hl_group = "ArrowSplitMode",
				})
			end
		end
	end

	---------------------------------------
	-- setting highlights for file paths --
	---------------------------------------
	local pattern = " %. .-$"
	local line_number = 1
	while line_number <= #fileNames + 1 do
		local line_content = vim.api.nvim_buf_get_lines(menuBuf, line_number - 1, line_number, false)[1]

		if line_content then
			local match_start, match_end = string.find(line_content, pattern)
			if match_start then
				vim.api.nvim_buf_set_extmark(menuBuf, namespace, line_number - 1, match_start - 1, {
					end_col = match_end,
					hl_group = "ArrowAction",
				})
			end
		end

		line_number = line_number + 1
	end

	-- setting conditional border highlight TODO
	-- local bookmark_type = config.getState("current_bookmark_type")
	-- local borderHighlightKey = bookmark_type == "dir" and "ArrowDirBorder" or "ArrowFileBorder"
	-- local borderHighlight = vim.api.nvim_get_hl(0, { name = borderHighlightKey })
	-- print(vim.inspect(borderHighlight))
	-- if borderHighlight.fg then
	-- 	vim.api.nvim_set_hl(namespace, "FloatBorder", {
	-- 		fg = borderHighlight.fg,
	-- 	})
	-- end
end

-- Function to open the selected file or directory
function M.openFile(fileNumber)
	local bookmark_type = config.getState("current_bookmark_type")
	local fileName = bookmark_type == "dir" and vim.g.arrow_dir_bookmarks[fileNumber]
		or vim.g.arrow_filenames[fileNumber]

	if vim.b.arrow_current_mode == "delete_mode" then
		if bookmark_type == "dir" then
			persist.remove_dir(fileName)
		else
			persist.remove(fileName)
		end

		fileNames = bookmark_type == "dir" and vim.g.arrow_dir_bookmarks or vim.g.arrow_filenames

		renderBuffer(vim.api.nvim_get_current_buf())
		render_highlights(vim.api.nvim_get_current_buf())
	else
		if not fileName then
			print("Invalid " .. bookmark_type .. " number")

			return
		end

		local action

		fileName = vim.fn.fnameescape(fileName)

		if vim.b.arrow_current_mode == "" or not vim.b.arrow_current_mode then
			if bookmark_type == "dir" then
				local dir_config = config.getState("dir_bookmark_config")
				action = dir_config and dir_config.open_action
			else
				action = config.getState("open_action")
			end
		elseif vim.b.arrow_current_mode == "vertical_mode" then
			if bookmark_type ~= "dir" then
				action = config.getState("vertical_action")
			else
				local dir_config = config.getState("dir_bookmark_config")
				action = dir_config and dir_config.open_action
			end
		elseif vim.b.arrow_current_mode == "horizontal_mode" then
			if bookmark_type ~= "dir" then
				action = config.getState("horizontal_action")
			else
				local dir_config = config.getState("dir_bookmark_config")
				action = dir_config and dir_config.open_action
			end
		end

		closeMenu()
		vim.api.nvim_exec_autocmds("User", { pattern = "ArrowOpenFile" })

		if bookmark_type == "dir" then
			-- For directory bookmarks, just pass the directory path
			action(fileName, vim.b.filename)
		elseif
			config.getState("global_bookmarks") == true
			or config.getState("save_key_name") == "cwd"
			or config.getState("save_key_name") == "git_root_bare"
		then
			action(fileName, vim.b.filename)
		else
			action(config.getState("save_key_cached") .. "/" .. fileName, vim.b.filename)
		end
	end
end

function M.getWindowConfig()
	local show_handbook = not (config.getState("hide_handbook"))
	local parsedFileNames = format_file_names(fileNames)
	local separate_save_and_remove = config.getState("separate_save_and_remove")
	local bookmark_type = config.getState("current_bookmark_type")
	local mappings = config.getState("mappings")
	local actionsMenu = getActionsMenu()

	local max_width = 0
	if show_handbook then
		max_width = 15
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
		height = height + #actionsMenu
		if separate_save_and_remove then
			height = height + 1
		end
	end

	local current_config = {
		width = width,
		height = height,
		row = math.ceil((vim.o.lines - height) / 2),
		col = math.ceil((vim.o.columns - width) / 2),
		title = bookmark_type == "dir" and " directories " or " files ",
		title_pos = "left",
		footer = string.format(" %s switch ", mappings.toggle_bookmark_type),
		footer_pos = "center",
	}

	local bookmark_list = bookmark_type == "dir" and vim.g.arrow_dir_bookmarks or vim.g.arrow_filenames
	local is_empty = #bookmark_list == 0

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

function M.openMenu(bufnr)
	git.refresh_git_branch()

	-- Always default to file bookmarks when opening the menu
	-- config.setState("current_bookmark_type", type or "file")

	local call_buffer = bufnr or vim.api.nvim_get_current_buf()

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

	local buffer_leader_key = config.getState("buffer_leader_key")
	if buffer_leader_key then
		vim.keymap.set("n", buffer_leader_key, function()
			closeMenu()

			vim.schedule(function()
				require("arrow.buffer_ui").openMenu(call_buffer)
			end)
		end, menuKeymapOpts)
	end

	vim.keymap.set("n", mappings.quit, closeMenu, menuKeymapOpts)
	vim.keymap.set("n", mappings.edit, function()
		closeMenu()
		local bookmark_type = config.getState("current_bookmark_type")
		persist.open_cache_file(bookmark_type)
	end, menuKeymapOpts)

	if separate_save_and_remove then
		vim.keymap.set("n", mappings.toggle, function()
			local bookmark_type = config.getState("current_bookmark_type")
			filename = filename or utils.get_current_buffer_path()
			if bookmark_type == "dir" then
				local current_dir = vim.fn.fnamemodify(filename, ":h") .. "/"
				persist.save_dir(current_dir)
			else
				persist.save(filename)
			end
			closeMenu()
		end, menuKeymapOpts)

		vim.keymap.set("n", mappings.remove, function()
			local bookmark_type = config.getState("current_bookmark_type")
			filename = filename or utils.get_current_buffer_path()

			if bookmark_type == "dir" then
				local current_dir = vim.fn.fnamemodify(filename, ":h") .. "/"
				persist.remove_dir(current_dir)
			else
				persist.remove(filename)
			end
			closeMenu()
		end, menuKeymapOpts)
	else
		vim.keymap.set("n", mappings.toggle, function()
			local bookmark_type = config.getState("current_bookmark_type")
			if bookmark_type == "dir" then
				local current_file = utils.get_current_buffer_path()
				local current_dir = vim.fn.fnamemodify(current_file, ":h") .. "/"
				persist.toggle_dir(current_dir)
			else
				persist.toggle(filename)
			end
			closeMenu()
		end, menuKeymapOpts)
	end

	vim.keymap.set("n", mappings.clear_all_items, function()
		local bookmark_type = config.getState("current_bookmark_type")
		if bookmark_type == "dir" then
			persist.clear_dir()
		else
			persist.clear()
		end
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

	vim.keymap.set("n", mappings.toggle_bookmark_type, function()
		local current_type = config.getState("current_bookmark_type")
		local new_type = current_type == "file" and "dir" or "file"
		config.setState("current_bookmark_type", new_type)

		renderBuffer(menuBuf)
		render_highlights(menuBuf)
		refreshMenu()
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

	vim.api.nvim_set_hl(0, "ArrowCursor", { nocombine = true, blend = 100 })
	vim.opt.guicursor:append("a:ArrowCursor/ArrowCursor")

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = 0,
		desc = "Disable Cursor",
		once = true,
		callback = function()
			current_index = 0

			vim.cmd("highlight clear ArrowCursor")
			vim.schedule(function()
				vim.opt.guicursor:remove("a:ArrowCursor/ArrowCursor")
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
