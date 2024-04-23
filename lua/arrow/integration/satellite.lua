local api = vim.api
local persist = require("arrow.buffer_persist")
local success, util = pcall(require,"satellite.util")
if not success then
    return {}
end

local HIGHLIGHT = "BookmarkSign"

local handler = {
    name = "arrow",
}

local function setup_hl()
    api.nvim_set_hl(0, HIGHLIGHT, {
        default = true,
        fg = api.nvim_get_hl(0, { name = "Normal" }).fg,
    })
end

local config = {
    enable = true,
    overlap = true,
    priority = 1000,
}

function handler.setup(config0, update)
    config = vim.tbl_deep_extend("force", config, config0)
    handler.config = config
    local group = api.nvim_create_augroup("satellite_arrow_marks", {})
    setup_hl()
    api.nvim_create_autocmd("User", {
        group = group,
        pattern = "ArrowMarkUpdate",
        callback = vim.schedule_wrap(update),
    })
end

function handler.update(bufnr, winid)
    local ret = {}

    local marks = persist.get_bookmarks_by(bufnr)
    if marks then
        for i, mark in ipairs(marks) do
            local pos = util.row_to_barpos(winid, mark.line - 1)
            ret[#ret + 1] = {
                pos = pos,
                highlight = HIGHLIGHT,
                symbol = tostring(i),
            }
        end
    end

    return ret
end

require("satellite.handlers").register(handler)
