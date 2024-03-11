local M = {}

function M.cwd()
	return vim.loop.cwd()
end

function M.git_root()
	return vim.fn.system("git rev-parse --show-toplevel | tr -d '\n'")
end

return M
