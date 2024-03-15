local M = {}

local config = require("arrow.config")

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

function M.get_path_for(buffer)
	local bufname = vim.fn.bufname(buffer)

	local save_key = config.getState("save_key")()

	local escaped_cwd = save_key:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")

	if bufname:find("^" .. escaped_cwd .. "/") then
		local relative_path = bufname:gsub("^" .. escaped_cwd .. "/", "")
		return relative_path
	else
		return bufname
	end
end

return M
