local M = {}

function M.cwd()
	return vim.uv.cwd()
end

function M.git_root()
	local git_root = vim.fn.system("git rev-parse --show-toplevel 2>&1")

	if vim.v.shell_error == 0 then
		return git_root:gsub("\n$", "")
	end

	return M.cwd()
end

function M.git_root_bare()
	local git_bare_root = vim.fn.system("git rev-parse --path-format=absolute --git-common-dir 2>&1")

	if vim.v.shell_error == 0 then
		git_bare_root = git_bare_root:gsub("/%.git\n$", "")
		return git_bare_root:gsub("\n$", "")
	end

	return M.cwd()
end

return M
