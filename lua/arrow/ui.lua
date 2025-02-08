local M = {}

local config = require("arrow.config")
local persist = require("arrow.persist")
local utils = require("arrow.utils")
local git = require("arrow.git")
local icons = require("arrow.integration.icons")

local fileNames = {}
local to_highlight = {}
local lines = {}

local current_index = 0

M.dictionary = ""

local function is_key_in_mappings(key, mappings)
	for _, mapping_key in pairs(mappings) do
		if mapping_key == key then
			return true
		end
	end
	return false
end

local function calculate_dictionary()
	local base_dictionary = "sadflewcmpghio"
	local mappings = config.getState("mappings")

	-- Initialize an empty result dictionary
	local result_dictionary = ""

	-- Loop through the base dictionary and exclude conflicting keys
	for i = 1, #base_dictionary do
		local key = base_dictionary:sub(i, i)

		-- Only add the key to result_dictionary if it's not in the user's mappings
		if not is_key_in_mappings(key, mappings) then
			result_dictionary = result_dictionary .. key
		end
	end

	-- Update the module-level dictionary with the filtered result
	M.dictionary = result_dictionary
end

local function getActionsMenu()
	local mappings = config.getState("mappings")
	local global_bookmarks = require("arrow.global_bookmarks").global_bookmarks
	local separate_save_and_remove = config.getState("separate_save_and_remove")
	local already_saved = current_index > 0
	local is_in_global = false
	local filename = vim.fn.expand("%:p")

	-- Check if current file is in global bookmarks
	for _, bookmark in ipairs(global_bookmarks) do
		if bookmark == filename then
			is_in_global = true
			break
		end
	end

	local local_bookmarks_count = #vim.g.arrow_filenames
	local global_bookmarks_count = #global_bookmarks

	-- Initialize basic actions that should always be shown
	local return_mappings = {
		string.format("%s Quit", mappings.quit),
	}

	-- Handle global bookmark action based on separate_save_and_remove setting
	if separate_save_and_remove then
		if is_in_global then
			table.insert(return_mappings, string.format("%s Remove from Global", mappings.remove_global))
		else
			-- Only show Add to Global if not already in global bookmarks
			table.insert(return_mappings, string.format("%s Add to Global", mappings.toggle_global))
		end
	else
		if is_in_global then
			table.insert(return_mappings, string.format("%s Remove from Global", mappings.toggle_global))
		else
			table.insert(return_mappings, string.format("%s Add to Global", mappings.toggle_global))
		end
	end

	-- If we have any bookmarks (global or local), or if someone is currently saving one
	if local_bookmarks_count > 0 or global_bookmarks_count > 0 or vim.b.arrow_current_mode then
		table.insert(return_mappings, string.format("%s Edit Arrow File", mappings.edit))
		table.insert(return_mappings, string.format("%s Edit Global Bookmarks", mappings.edit_global))
		table.insert(return_mappings, string.format("%s Delete mode", mappings.delete_mode))
		table.insert(return_mappings, string.format("%s Clear All Local Items", mappings.clear_all_items))
		table.insert(return_mappings, string.format("%s Open Vertical", mappings.open_vertical))
		table.insert(return_mappings, string.format("%s Open Horizontal", mappings.open_horizontal))
		table.insert(return_mappings, string.format("%s Next Item", mappings.next_item))
		table.insert(return_mappings, string.format("%s Prev Item", mappings.prev_item))
	end

	-- Handle local bookmark action based on separate_save_and_remove setting
	if separate_save_and_remove then
		if already_saved then
			table.insert(return_mappings, string.format("%s Remove Current File", mappings.remove))
		else
			table.insert(return_mappings, string.format("%s Save Current File", mappings.toggle))
		end
	else
		if already_saved then
			table.insert(return_mappings, 1, string.format("%s Remove Current File", mappings.toggle))
		else
			table.insert(return_mappings, 1, string.format("%s Save Current File", mappings.toggle))
		end
	end

	return return_mappings
end

local function format_single_filename(full_path, show_icons, line_number, is_global)
	local formatted_name = ""
	local full_path_list = config.getState("full_path_list")

	-- Handle directory paths
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

			if config.getState("always_show_path") then
				formatted_name = string.format("%s . %s", folder_name .. "/", location)
			else
				formatted_name = string.format("%s", folder_name .. "/")
			end
		else
			if config.getState("always_show_path") then
				formatted_name = full_path .. " . /"
			else
				formatted_name = full_path
			end
		end
	else
		-- Handle regular files
		local tail = vim.fn.fnamemodify(full_path, ":t:r")
		local tail_with_extension = vim.fn.fnamemodify(full_path, ":t")
		local path = vim.fn.fnamemodify(full_path, ":h")

		-- Always show path for regular files when not in special cases
		if not is_global and path ~= "." then
			formatted_name = string.format("%s . %s", tail_with_extension, path)
		else
			formatted_name = tail_with_extension
		end
	end

	if show_icons then
		local icon, hl_group = icons.get_file_icon(full_path)
		to_highlight[#to_highlight + 1] = { pos = line_number, hl = hl_group, col = 5 }
		return icon .. " " .. formatted_name
	end

	return formatted_name
end

local function format_file_names(file_names)
	local full_path_list = config.getState("full_path_list")
	local formatted_names = {}

	print("\n=== Debug Format File Names ===")
	print("Number of files to format:", #file_names)

	-- First pass: count occurrences
	local name_occurrences = {}
	for i, full_path in ipairs(file_names) do
		local tail = vim.fn.fnamemodify(full_path, ":t:r")
		print(string.format("\nFile %d:", i))
		print("Full path:", full_path)
		print("Tail:", tail)

		if vim.fn.isdirectory(full_path) == 1 then
			print("Type: Directory")
			local parsed_path = full_path:gsub("/$", "")
			local folder_name = vim.fn.fnamemodify(parsed_path, ":t")

			name_occurrences[folder_name] = name_occurrences[folder_name] or {}
			table.insert(name_occurrences[folder_name], full_path)
			print("Folder name:", folder_name)
			print("Occurrences:", #name_occurrences[folder_name])
		else
			print("Type: File")
			name_occurrences[tail] = name_occurrences[tail] or {}
			table.insert(name_occurrences[tail], full_path)
			print("Occurrences:", #name_occurrences[tail])
		end
	end

	-- Second pass: format names
	for i, full_path in ipairs(file_names) do
		print(string.format("\nFormatting file %d:", i))
		print("Path:", full_path)

		local tail = vim.fn.fnamemodify(full_path, ":t:r")
		local tail_with_extension = vim.fn.fnamemodify(full_path, ":t")
		print("Tail:", tail)
		print("Tail with ext:", tail_with_extension)

		if vim.fn.isdirectory(full_path) == 1 then
			print("Processing directory...")
			if not full_path:match("/$") then
				full_path = full_path .. "/"
			end

			local path = vim.fn.fnamemodify(full_path, ":h")
			local folder_name = vim.fn.fnamemodify(path, ":t")
			local location = vim.fn.fnamemodify(full_path, ":h:h")

			local formatted = string.format("%s . %s", folder_name .. "/", location)
			print("Formatted directory:", formatted)
			table.insert(formatted_names, formatted)
		else
			print("Processing file...")
			local show_path = config.getState("always_show_path")
				or (name_occurrences[tail] and #name_occurrences[tail] > 1)
				or vim.tbl_contains(full_path_list, tail)

			print("Show path:", show_path)
			print("In full_path_list:", vim.tbl_contains(full_path_list, tail))
			print("Occurrences:", #name_occurrences[tail])

			if show_path then
				local path = vim.fn.fnamemodify(full_path, ":h")
				local formatted = string.format("%s . %s", tail_with_extension, path)
				print("Formatted with path:", formatted)
				table.insert(formatted_names, formatted)
			else
				print("Formatted without path:", tail_with_extension)
				table.insert(formatted_names, tail_with_extension)
			end
		end
	end

	return formatted_names
end

-- Function to close the menu and open the selected file
local function closeMenu()
	local win = vim.fn.win_getid()
	vim.api.nvim_win_close(win, true)
end

local function render_highlights(buffer)
	local actionsMenu = getActionsMenu()
	local mappings = config.getState("mappings")
	local global_bookmarks = require("arrow.global_bookmarks").global_bookmarks

	vim.api.nvim_buf_clear_namespace(buffer, -1, 0, -1)
	local menuBuf = buffer or vim.api.nvim_get_current_buf()

	-- Debug all highlights at start
	print("\n=== All Icon Highlights ===")
	for i, highlight in ipairs(to_highlight) do
		print(string.format("Highlight %d: pos=%d, col=%d, hl=%s", i, highlight.pos, highlight.col, highlight.hl))
	end

	-- Highlight section headers
	vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowHeader", 0, 3, -1)
	local local_header_pos = 2 + math.max(1, #global_bookmarks)
	vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowHeader", local_header_pos, 3, -1)

	-- Handle file type icons
	if config.getState("show_icons") then
		for _, highlight in ipairs(to_highlight) do
			if highlight.hl and type(highlight.hl) == "string" then
				if highlight.pos > 1 then
					vim.api.nvim_buf_add_highlight(
						menuBuf,
						-1,
						highlight.hl,
						highlight.pos - 1,
						highlight.col,
						highlight.col + 2
					)
				end
			end
		end
	end

	-- Global bookmarks section debug
	print("\n=== Global Bookmarks ===")
	for i = 1, #global_bookmarks do
		local line_idx = i + 1
		local line = vim.api.nvim_buf_get_lines(menuBuf, line_idx - 1, line_idx, false)[1]
		if line then
			print(string.format("Global bookmark %d at line %d: '%s'", i, line_idx, line))
		end
	end

	-- Local bookmarks section with comprehensive debugging
	print("\n=== Local Bookmarks ===")
	for i = 1, #fileNames do
		local actual_line = local_header_pos + i
		local line = vim.api.nvim_buf_get_lines(menuBuf, actual_line, actual_line + 1, false)[1]

		if line then
			-- Debug complete line info
			print(string.format("\nLocal bookmark %d at line %d:", i, actual_line))
			print("Full line content: '" .. line .. "'")

			-- Debug icon and highlight positions
			local content_start = config.getState("show_icons") and 9 or 5
			print(string.format("Content start: %d", content_start))

			-- Find icon highlight for this line
			for _, highlight in ipairs(to_highlight) do
				if highlight.pos == actual_line + 1 then
					print(
						string.format(
							"Icon highlight found: pos=%d, col=%d, hl=%s",
							highlight.pos,
							highlight.col,
							highlight.hl
						)
					)
				end
			end

			-- Handle index highlight
			if vim.b.arrow_current_mode == "delete_mode" then
				vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowDeleteMode", actual_line, 3, 4)
			else
				vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowFileIndex", actual_line, 3, 4)
			end

			local bookmark_text = line:sub(content_start + 1)
			print("Extracted bookmark text: '" .. bookmark_text .. "'")

			local separator_pos = bookmark_text:find(" %.")
			if separator_pos then
				print(string.format("Separator found at position: %d", separator_pos))
				vim.api.nvim_buf_add_highlight(
					menuBuf,
					-1,
					"ArrowFileName",
					actual_line,
					content_start,
					content_start + separator_pos
				)
				vim.api.nvim_buf_add_highlight(
					menuBuf,
					-1,
					"ArrowFilePath",
					actual_line,
					content_start + separator_pos + 1,
					-1
				)
			else
				print("No separator found, highlighting full line")
				vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowFileName", actual_line, content_start, -1)
			end
		end
	end

	-- Calculate action menu start position and highlight actions
	local local_section_height = math.max(1, #fileNames)
	local action_start = local_header_pos + local_section_height + 2

	-- Highlight action shortcuts
	for i = 0, #actionsMenu - 1 do
		local line = vim.api.nvim_buf_get_lines(menuBuf, action_start + i, action_start + i + 1, false)[1]
		if line then
			vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowAction", action_start + i, 3, 4)

			if vim.b.arrow_current_mode == "delete_mode" and line:match(mappings.delete_mode .. " Delete mode") then
				vim.api.nvim_buf_add_highlight(menuBuf, -1, "ArrowDeleteMode", action_start + i, 0, -1)
			end
		end
	end
end

local function renderBuffer(buffer)
	vim.api.nvim_buf_set_option(buffer, "modifiable", true)

	local show_icons = config.getState("show_icons")
	local buf = buffer or vim.api.nvim_get_current_buf()
	lines = {}
	to_highlight = {}

	-- Get fresh copy of global bookmarks
	local global_bookmarks = require("arrow.global_bookmarks")
	local bookmarks = global_bookmarks.global_bookmarks

	-- Start building lines
	table.insert(lines, "   Global Bookmarks:")

	if #bookmarks > 0 then
		for i, fileName in ipairs(bookmarks) do
			if i <= #M.dictionary then
				local displayKey = M.dictionary:sub(i, i)
				local formatted_name = format_single_filename(fileName, show_icons, #lines + 1, true)

				local line = string.format("   %s %s", displayKey, formatted_name)

				table.insert(lines, line)
			end
		end
	else
		table.insert(lines, "   No global bookmarks")
	end

	-- Add spacing between sections
	table.insert(lines, "")

	-- Local bookmarks section
	table.insert(lines, "   Local Bookmarks:")
	if #fileNames > 0 then
		for i, fileName in ipairs(fileNames) do
			local displayIndex = config.getState("index_keys"):sub(i, i)
			local formatted_name = format_single_filename(fileName, show_icons, #lines + 1, false)
			table.insert(lines, string.format("   %s %s", displayIndex, formatted_name))
		end
	else
		table.insert(lines, "   No local bookmarks")
	end

	-- Single line spacing before actions
	table.insert(lines, "")

	-- Add actions menu
	if not (config.getState("hide_handbook")) then
		local actionsMenu = getActionsMenu()
		for _, action in ipairs(actionsMenu) do
			table.insert(lines, "   " .. action)
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	render_highlights(buf)

	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

-- Function to create the menu buffer with a list format
local function createMenuBuffer(filename)
	local buf = vim.api.nvim_create_buf(false, true)

	vim.b[buf].filename = filename
	vim.b[buf].arrow_current_mode = ""
	renderBuffer(buf)

	return buf
end

-- Function to open the selected file
function M.openFile(fileNumber, isGlobal)
	if isGlobal then
		local global_bookmarks = require("arrow.global_bookmarks").global_bookmarks
		local fileName = global_bookmarks[fileNumber]

		if vim.b.arrow_current_mode == "delete_mode" then
			require("arrow.global_bookmarks").remove(fileNumber)
			renderBuffer(vim.api.nvim_get_current_buf())
		else
			if fileName then
				closeMenu()
				-- Always use the absolute path stored in global_bookmarks
				-- which is already absolute since we fixed the save process
				vim.cmd(":edit " .. vim.fn.fnameescape(fileName))
			end
		end
	else
		local fileName = vim.g.arrow_filenames[fileNumber]

		if vim.b.arrow_current_mode == "delete_mode" then
			persist.remove(fileName)
			fileNames = vim.g.arrow_filenames
			renderBuffer(vim.api.nvim_get_current_buf())
		else
			if fileName then
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

				if
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
	end
end

function M.getWindowConfig()
	local global_bookmarks = require("arrow.global_bookmarks").global_bookmarks
	local show_handbook = not (config.getState("hide_handbook"))
	local parsedFileNames = format_file_names(fileNames)
	local separate_save_and_remove = config.getState("separate_save_and_remove")

	-- Calculate max width needed for filenames
	local max_width = 0
	for _, v in pairs(parsedFileNames) do
		if #v > max_width then
			max_width = #v
		end
	end

	-- Check global bookmarks for max width
	for _, v in pairs(global_bookmarks) do
		local formatted = format_single_filename(v, false, 0, true)
		if #formatted > max_width then
			max_width = #formatted
		end
	end

	-- Check action menu items for max width
	local actionsMenu = getActionsMenu()
	for _, action in ipairs(actionsMenu) do
		if #action > max_width then
			max_width = #action
		end
	end

	-- Add padding for index and icons
	local width = max_width + 12

	-- Ensure minimum width for empty state
	if #vim.g.arrow_filenames == 0 and #global_bookmarks == 0 then
		width = math.max(width, 35)
	end

	-- Calculate base height for section headers and spacing
	local height = 4 -- Start with: Global header (1) + Local header (1) + 2 spacer lines

	-- Add height for bookmarks sections
	if #global_bookmarks > 0 then
		height = height + #global_bookmarks
	else
		height = height + 1 -- "No global bookmarks" line
	end

	if #fileNames > 0 then
		height = height + #fileNames
	else
		height = height + 1 -- "No local bookmarks" line
	end

	-- Add height for actions menu
	if show_handbook then
		-- When no bookmarks exist, we show fewer actions
		if #vim.g.arrow_filenames == 0 and #global_bookmarks == 0 then
			height = height + 3 -- Save/Toggle + Add Global + Quit
		else
			height = height + #actionsMenu + 1 -- +1 for spacing before actions
		end
	end

	local current_config = {
		width = width,
		height = height,
		row = math.ceil((vim.o.lines - height) / 2),
		col = math.ceil((vim.o.columns - width) / 2),
	}

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

	local call_buffer = bufnr or vim.api.nvim_get_current_buf()

	if vim.g.arrow_filenames == 0 then
		persist.load_cache_file()
	end

	-- Force reload global bookmarks before creating menu
	local global_bookmarks = require("arrow.global_bookmarks")
	global_bookmarks.load_cache_file()
	calculate_dictionary()

	to_highlight = {}
	fileNames = vim.g.arrow_filenames
	local filename = vim.fn.expand("%:p")
	local relative_filename = utils.get_current_buffer_path()

	-- Set current_index based on whether the file is saved
	current_index = persist.is_saved(filename) or 0

	local menuBuf = createMenuBuffer(filename)
	local window_config = M.getWindowConfig()
	local win = vim.api.nvim_open_win(menuBuf, true, window_config)

	local mappings = config.getState("mappings")
	local separate_save_and_remove = config.getState("separate_save_and_remove")
	local menuKeymapOpts = {
		noremap = true, -- Don't use existing mappings
		silent = true, -- Don't show messages
		buffer = menuBuf, -- Local to menu buffer
		nowait = true, -- Don't wait for other potential mappings
		desc = "Arrow menu action", -- Description for the mapping
	}

	-- Basic navigation
	if config.getState("leader_key") then
		vim.keymap.set("n", config.getState("leader_key"), closeMenu, menuKeymapOpts)
	end
	vim.keymap.set("n", mappings.quit, closeMenu, menuKeymapOpts)
	vim.keymap.set("n", "<Esc>", closeMenu, menuKeymapOpts)

	-- Global bookmark keymaps
	for i = 1, #global_bookmarks.global_bookmarks do
		if i <= #M.dictionary then
			local key = M.dictionary:sub(i, i)
			-- Set the keymap with override option
			vim.keymap.set("n", key, function()
				if vim.b.arrow_current_mode == "delete_mode" then
					local gb = require("arrow.global_bookmarks")
					if gb.remove(i) then
						vim.b.arrow_current_mode = "delete_mode" -- Stay in delete mode
						renderBuffer(menuBuf)
					end
				else
					M.openFile(i, true)
				end
			end, menuKeymapOpts)
		end
	end

	-- Local bookmark number keymaps
	local indexes = config.getState("index_keys")
	for i = 1, #fileNames do
		if i and indexes:sub(i, i) then
			vim.keymap.set("n", indexes:sub(i, i), function()
				M.openFile(i, false)
			end, menuKeymapOpts)
		end
	end

	-- Buffer leader key
	local buffer_leader_key = config.getState("buffer_leader_key")
	if buffer_leader_key then
		vim.keymap.set("n", buffer_leader_key, function()
			closeMenu()
			vim.schedule(function()
				require("arrow.buffer_ui").openMenu(call_buffer)
			end)
		end, menuKeymapOpts)
	end

	-- Standard operations
	vim.keymap.set("n", mappings.edit, function()
		closeMenu()
		persist.open_cache_file()
	end, menuKeymapOpts)

	vim.keymap.set("n", mappings.edit_global, function()
		closeMenu()
		require("arrow.global_bookmarks").open_cache_file()
	end, menuKeymapOpts)

	-- Global and local bookmark mappings
	if separate_save_and_remove then
		local is_in_global = false

		-- Check if current file is in global bookmarks using absolute paths
		for _, bookmark in ipairs(global_bookmarks.global_bookmarks) do
			if bookmark == filename then
				is_in_global = true
				break
			end
		end

		-- Global bookmark keymaps
		if is_in_global then
			vim.keymap.set("n", mappings.remove_global, function()
				local gb = require("arrow.global_bookmarks")
				for i, bookmark in ipairs(gb.global_bookmarks) do
					if bookmark == filename then
						gb.remove(i)
						break
					end
				end
				closeMenu()
			end, menuKeymapOpts)
		else
			vim.keymap.set("n", mappings.toggle_global, function()
				if vim.b.arrow_current_mode ~= "delete_mode" then
					local gb = require("arrow.global_bookmarks")
					gb.save(filename)
					closeMenu()
				end
			end, menuKeymapOpts)
		end

		-- Local bookmark keymaps for separate save/remove
		if persist.is_saved(relative_filename) then
			vim.keymap.set("n", mappings.remove, function()
				persist.remove(relative_filename)
				closeMenu()
			end, menuKeymapOpts)
		else
			vim.keymap.set("n", mappings.toggle, function()
				persist.save(relative_filename)
				closeMenu()
			end, menuKeymapOpts)
		end
	else
		-- Global bookmark toggle mapping for combined mode
		vim.keymap.set("n", mappings.toggle_global, function()
			if vim.b.arrow_current_mode ~= "delete_mode" then
				local gb = require("arrow.global_bookmarks")
				local found = false
				for i, bookmark in ipairs(gb.global_bookmarks) do
					if bookmark == filename then
						gb.remove(i)
						found = true
						break
					end
				end
				if not found then
					gb.save(filename)
				end
				closeMenu()
			end
		end, menuKeymapOpts)

		-- Local bookmark toggle mapping for combined mode
		vim.keymap.set("n", mappings.toggle, function()
			persist.toggle(relative_filename)
			closeMenu()
		end, menuKeymapOpts)
	end

	vim.keymap.set("n", mappings.clear_all_items, function()
		persist.clear()
		closeMenu()
	end, menuKeymapOpts)

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

	vim.keymap.set("n", mappings.next_item, function()
		closeMenu()
		persist.next()
	end, menuKeymapOpts)

	vim.keymap.set("n", mappings.prev_item, function()
		closeMenu()
		persist.previous()
	end, menuKeymapOpts)

	-- Set up cursor and window options
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

	vim.wo.cursorline = false
	vim.api.nvim_set_current_win(win)
	render_highlights(menuBuf)
end

-- Command to trigger the menu
return M
