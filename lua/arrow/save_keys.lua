local M = {}

function M.cwd()
	return vim.loop.cwd()
end

function M.git_root()
	local git_root = vim.fn.system("git rev-parse --show-toplevel 2>&1")

	if vim.v.shell_error == 0 then
		return git_root:gsub("\n$", "")
	end

	return M.cwd()
end

return M
