local M = {}

local config = require("arrow.config")
local utils = require("arrow.utils")
local ui = require("arrow.ui")
local persist = require("arrow.persist")

M.config = {}

function M.setup(opts)
	opts = opts or {}

	local default_mappings = {
		edit = "e",
		delete_mode = "d",
		clear_all_items = "C",
		toggle = "s",
		open_vertical = "|",
		open_horizontal = "-",
		quit = "q",
	}

	local leader_key = opts.leader_key or ";"

	config.setState("leader_key", leader_key)
	config.setState("show_icons", opts.show_icons)
	config.setState("icons", opts.icons)
	config.setState("after_9_keys", opts.after_9_keys or "zxcvbnmZXVBNM,afghjklAFGHJKLwrtyuiopWRTYUIOP")

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
		"middleware",
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
		"encrypt",
		"decrypt",
		"compress",
		"decompress",
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
		"listen",
		"notify",
		"subscribe",
		"unsubscribe",
		"connect",
		"disconnect",
		"enable",
		"disable",
		"refresh",
		"reset",
	}

	config.setState("mappings", utils.join_two_keys_tables(default_mappings, opts.mappings or {}))
	config.setState("full_path_list", utils.join_two_arrays(default_full_path_list, opts.full_path_list or {}))

	persist.load_cache_file()
end

M.setup({ mappings = { quit = "q" }, full_path_list = { "set", "init" } })

return M
