local M = {}

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

return M
