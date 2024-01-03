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
		quit = "q",
	}

	local leader_key = opts.leader_key or ";"

	config.setState("leader_key", leader_key)
	config.setState("show_icons", opts.show_icons)

	config.setState("save_key", opts.save_key or function()
		return vim.loop.cwd()
	end)

	if leader_key then
		vim.keymap.set("n", leader_key, ui.openMenu, { noremap = true, silent = true })
	end

	local default_full_path_list = { "create" }

	config.setState("mappings", utils.join_two_keys_tables(default_mappings, opts.mappings or {}))
	config.setState("full_path_list", utils.join_two_arrays(default_full_path_list, opts.full_path_list or {}))

	persist.load_cache_file()
end

M.setup({ mappings = { quit = "q" }, full_path_list = { "set", "init" } })

return M
