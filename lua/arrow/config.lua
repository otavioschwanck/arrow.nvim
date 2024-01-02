local M = {}

M.config = {}

function M.setState(key, value)
	M.config[key] = value
end

function M.getState(key)
	return M.config[key]
end

return M
