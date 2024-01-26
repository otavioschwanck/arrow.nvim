local M = {}

local config = require("arrow.config")
local utils = require("arrow.utils")
local ui = require("arrow.ui")
local persist = require("arrow.persist")

M.config = {}

function M.setup(opts)
	vim.cmd("highlight default link ArrowFileIndex CursorLineNr")
	vim.cmd("highlight default link ArrowCurrentFile SpecialChar")
	vim.cmd("highlight default link ArrowAction Character")
	vim.cmd("highlight default link ArrowDeleteMode DiagnosticError")

	opts = opts or {}

	local default_mappings = {
		edit = "e",
		delete_mode = "d",
		clear_all_items = "C",
		toggle = "s",
		open_vertical = "v",
		open_horizontal = "-",
		quit = "q",
	}

	local leader_key = opts.leader_key or ";"

	config.setState("save_path", opts.save_path or function()
		return vim.fn.stdpath("cache") .. "/arrow"
	end)
	config.setState("leader_key", leader_key)
	config.setState("always_show_path", opts.always_show_path or false)
	config.setState("show_icons", opts.show_icons)
	config.setState("index_keys", opts.index_keys or "123456789zxcbnmZXVBNM,afghjklAFGHJKLwrtyuiopWRTYUIOP")
	config.setState("hide_handbook", opts.hide_handbook or false)
	config.setState("separate_by_branch", opts.separate_by_branch or false)

	config.setState("save_key", opts.save_key or function()
		return vim.loop.cwd()
	end)

	if leader_key then
		vim.keymap.set("n", leader_key, ui.openMenu, { noremap = true, silent = true })
	end

	local default_full_path_list = {
		"index",
		"main",
		"create",
		"update",
		"upgrade",
		"edit",
		"new",
		"delete",
		"list",
		"view",
		"show",
		"form",
		"controller",
		"service",
		"util",
		"utils",
		"config",
		"constants",
		"consts",
		"test",
		"spec",
		"handler",
		"route",
		"router",
		"run",
		"execute",
		"start",
		"stop",
		"setup",
		"cleanup",
		"init",
		"launch",
		"load",
		"save",
		"read",
		"write",
		"validate",
		"process",
		"handle",
		"parse",
		"format",
		"generate",
		"render",
		"authenticate",
		"authorize",
		"validate",
		"search",
		"filter",
		"sort",
		"paginate",
		"export",
		"import",
		"download",
		"upload",
		"submit",
		"cancel",
		"approve",
		"reject",
		"send",
		"receive",
		"notify",
		"enable",
		"disable",
		"reset",
	}

	config.setState("mappings", utils.join_two_keys_tables(default_mappings, opts.mappings or {}))
	config.setState("full_path_list", utils.join_two_arrays(default_full_path_list, opts.full_path_list or {}))

	persist.load_cache_file()

	vim.api.nvim_create_augroup("arrow", { clear = true })

	vim.api.nvim_create_autocmd({ "DirChanged" }, {
		callback = persist.load_cache_file,
		desc = "load cache file on DirChanged",
		group = "arrow",
	})
end

return M
