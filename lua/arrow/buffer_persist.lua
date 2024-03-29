local M = {}

local config = require("arrow.config")
local utils = require("arrow.utils")
local json = require("arrow.json")

local ns = vim.api.nvim_create_namespace("arrow_bookmarks")
M.local_bookmarks = {}

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		for bufnr, _ in pairs(M.local_bookmarks) do
			M.update(bufnr)
			M.sync_buffer_bookmarks(bufnr)
		end
	end,
})

local function save_key(filename)
	return utils.normalize_path_to_filename(filename)
end

function M.cache_file_path(filename)
	local save_path = config.getState("save_path")()

	save_path = save_path:gsub("/$", "")

	if vim.fn.isdirectory(save_path) == 0 then
		vim.fn.mkdir(save_path, "p")
	end

	return save_path .. "/" .. save_key(filename)
end

function M.load_buffer_bookmarks(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local path = M.cache_file_path(vim.fn.expand("%:p"))

	if vim.fn.filereadable(path) == 0 then
		M.local_bookmarks[bufnr] = {}
	else
		local f = assert(io.open(path, "rb"))

		local content = f:read("*all")

		f:close()

		local success, result = pcall(json.decode, content)
		if result ~= nil then
			for _, res in ipairs(result) do
				local line = res.line
				local id = vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, -1, {
					sign_text = "󰧌",
					sign_hl_group = "BookmarkSign",
					hl_mode = "combine",
				})
				res.ext_id = id
			end
		end
		if success then
			M.local_bookmarks[bufnr] = result
		else
			M.local_bookmarks[bufnr] = {}
		end
	end
end

function M.sync_buffer_bookmarks(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local buffer_file_name = vim.api.nvim_buf_get_name(bufnr)
	local path = M.cache_file_path(buffer_file_name)

	local path_dir = vim.fn.fnamemodify(path, ":h")

	if vim.fn.isdirectory(path_dir) == 0 then
		vim.fn.mkdir(path_dir, "p")
	end

	local file = io.open(path, "w")

	if file then
		if M.local_bookmarks[bufnr] == nil or #M.local_bookmarks[bufnr] == 0 then
			file:write("[]")
		else
			file:write(json.encode(M.local_bookmarks[bufnr]))
		end
		return true
	end

	return false
end

function M.is_saved(bufnr, bookmark)
	local saveds = M.get_bookmarks_by(bufnr)

	if saveds and #saveds > 0 then
		for _, saved in ipairs(saveds) do
			if utils.table_comp(saved, bookmark) then
				return true
			end
		end
	end

	return false
end

function M.remove(index, bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if M.local_bookmarks[bufnr] == nil then
		return
	end

	if M.local_bookmarks[bufnr][index] == nil then
		return
	end
	vim.api.nvim_buf_del_extmark(bufnr, ns, M.local_bookmarks[bufnr][index].ext_id)
	table.remove(M.local_bookmarks[bufnr], index)

	M.sync_buffer_bookmarks(bufnr)
end

function M.clear(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	M.local_bookmarks[bufnr] = {}
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	M.sync_buffer_bookmarks(bufnr)
end

function M.update(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { 0, 0 }, { -1, -1 }, {})
	if M.local_bookmarks[bufnr] ~= nil then
		for _, mark in ipairs(M.local_bookmarks[bufnr]) do
			for _, extmark in ipairs(extmarks) do
				local extmark_id, extmark_row, _ = unpack(extmark)
				if mark.ext_id == extmark_id and mark.line ~= extmark_row then
					mark.line = extmark_row + 1
				end
			end
		end
	end
end

function M.save(bufnr, line_nr, col_nr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if not M.local_bookmarks[bufnr] then
		M.local_bookmarks[bufnr] = {}
	end

	local id = vim.api.nvim_buf_set_extmark(bufnr, ns, line_nr - 1, -1, {
		sign_text = "󰧌",
		sign_hl_group = "BookmarkSign",
		hl_mode = "combine",
	})

	local data = {
		line = line_nr,
		col = col_nr,
		ext_id = id,
	}

	if not (M.is_saved(bufnr, data)) then
		table.insert(M.local_bookmarks[bufnr], data)

		M.sync_buffer_bookmarks(bufnr)
	end
end

function M.get_bookmarks_by(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	return M.local_bookmarks[bufnr]
end

return M
