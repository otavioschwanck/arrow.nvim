local M = {}
local config = require("arrow.config")

function M.get_git_branch()
	if vim.fn.isdirectory(".git") ~= 0 then
		return vim.fn.system("git branch --show-current | tr -d '\n'")
	else
		return nil
	end
end

function M.refresh_git_branch()
	if config.getState("separate_by_branch") then
		local current_branch = config.getState("current_branch")

		if current_branch ~= M.get_git_branch() then
			config.setState("current_branch", M.get_git_branch())
			require("arrow.persist").load_cache_file()
		end
	end

	return config.getState("current_branch")
end

return M
