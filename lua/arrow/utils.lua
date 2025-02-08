local M = {}

local config = require("arrow.config")

local DEBUG_MODE = false

function M.log(...)
	if DEBUG_MODE then
		vim.print(...)
	end
end

function M.table_comp(o1, o2)
	local callList = {}

	if o1 == o2 then
		return true
	end

	local o1Type = type(o1)
	local o2Type = type(o2)
	if o1Type ~= o2Type then
		return false
	end
	if o1Type ~= "table" then
		return false
	end

	-- add only when objects are tables, cache results
	local oComparisons = callList[o1]
	if not oComparisons then
		oComparisons = {}
		callList[o1] = oComparisons
	end
	-- false means that comparison is in progress
	oComparisons[o2] = false

	local keySet = {}
	for key1, value1 in pairs(o1) do
		local value2 = o2[key1]
		if value2 == nil then
			return false
		end

		local vComparisons = callList[value1]
		if not vComparisons or vComparisons[value2] == nil then
			if not M.table_comp(value1, value2, true, callList) then
				return false
			end
		end

		keySet[key1] = true
	end

	for key2, _ in pairs(o2) do
		if not keySet[key2] then
			return false
		end
	end

	-- comparison finished - objects are equal do not compare again
	oComparisons[o2] = true
	return true
end

---Memoize a function using hash_fn to hash the arguments.
---@generic F: function
---@param fn F
---@param hash_fn fun(...): any
---@return F
function M.memoize(fn, hash_fn)
	local cache = setmetatable({}, { __mode = "kv" }) ---@type table<any,any>

	return function(...)
		local key = hash_fn(...)
		if cache[key] == nil then
			local v = fn(...) ---@type any
			cache[key] = v ~= nil and v or vim.NIL
		end

		local v = cache[key]
		return v ~= vim.NIL and vim.deepcopy(v) or nil
	end
end

function M.normalize_path_to_filename(path)
	if vim.fn.has("win32") then
		path = path:gsub("\\", "/")
	end
	return path:gsub("/", "_")
end

function M.join_two_keys_tables(tableA, tableB)
	local newTable = {}

	for k, v in pairs(tableA) do
		newTable[k] = v
	end

	for k, v in pairs(tableB) do
		newTable[k] = v
	end

	return newTable
end

function M.join_two_arrays(tableA, tableB)
	local newTable = {}

	for _, v in ipairs(tableA) do
		table.insert(newTable, v)
	end

	for _, v in ipairs(tableB) do
		table.insert(newTable, v)
	end

	return newTable
end

function M.get_current_buffer_path()
	return M.get_buffer_path(vim.api.nvim_get_current_buf())
end

function M.get_buffer_path(bufnr)
	local bufname = vim.fn.bufname(bufnr)
	local absolute_buffer_path = vim.fn.fnamemodify(bufname, ":p")

	local save_key = config.getState("save_key_cached") or config.getState("save_key")()
	local escaped_save_key = save_key:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")

	if absolute_buffer_path:find("^" .. escaped_save_key .. "/") then
		if config.getState("save_key_name") == "git_root_bare" then
			return vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
		else
			local relative_path = absolute_buffer_path:gsub("^" .. escaped_save_key .. "/", "")
			return relative_path
		end
	else
		return absolute_buffer_path
	end
end

function M.string_contains_whitespace(str)
	return string.match(str, "%s") ~= nil
end

function M.setup_auto_close(bufnr, win_id)
	vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
		buffer = bufnr,
		once = true,
		callback = function()
			-- Only close if the window still exists
			if vim.api.nvim_win_is_valid(win_id) then
				vim.api.nvim_win_close(win_id, true)
			end
		end,
		desc = "Auto-close Arrow window on focus lost",
	})
end

return M
