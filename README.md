# arrow.nvim

Arrow.nvim is a plugin made to bookmarks files (like harpoon) using a single UI (and single keymap). 

Arrow can be customized for everyone needs.

Arrow also provides per buffer bookmarks that will can quickly jump to them. (And their position is automatically updated / persisted while you modify the file)

### Per Project / Global bookmarksL:
![arrow.nvim](https://i.imgur.com/mPdSC5s.png)
![arrow.nvim_gif](https://i.imgur.com/LcvG406.gif)
![arrow_buffers](https://i.imgur.com/Lll9YvY.gif)

## Installation

### Lazy

```lua
return {
  "otavioschwanck/arrow.nvim",
  opts = {
    show_icons = true,
    leader_key = ';', -- Recommended to be a single key
    buffer_leader_key = 'm', -- Per Buffer Mappings
  }
}
```

### Packer

```lua
use { 'otavioschwanck/arrow.nvim', config = function()
  require('arrow').setup({
    show_icons = true,
    leader_key = ';' -- Recommended to be a single key
    buffer_leader_key = 'm', -- Per Buffer Mappings
  })
end }
```

## Usage

Just press the leader_key set on setup and follow you heart. (Is that easy)

## Differences from harpoon:

- Single keymap needed
- Different UI to manage the bookmarks
- Statusline helpers
- Show only the filename (show path only when needed: same filename twice or too generic filename, like create, index, etc)
- Has colors and icons <3
- Has the delete mode to quickly delete items
- Files can be opened vertically or horizontally
- Still has the option to edit file

## Advanced Setup

```lua
{
  show_icons = true,
  always_show_path = false,
  separate_by_branch = false, -- Bookmarks will be separated by git branch
  hide_handbook = false, -- set to true to hide the shortcuts on menu.
  save_path = function()
    return vim.fn.stdpath("cache") .. "/arrow"
  end,
  mappings = {
    edit = "e",
    delete_mode = "d",
    clear_all_items = "C",
    toggle = "s", -- used as save if separate_save_and_remove is true
    open_vertical = "v",
    open_horizontal = "-",
    quit = "q",
    remove = "x", -- only used if separate_save_and_remove is true
    next_item = "]",
    prev_item = "["
  },
  custom_actions = {
    open = function(target_file_name, current_file_name) end, -- target_file_name = file selected to be open, current_file_name = filename from where this was called
    split_vertical = function(target_file_name, current_file_name) end,
    split_horizontal = function(target_file_name, current_file_name) end,
  },
  window = { -- controls the appearance and position of an arrow window (see nvim_open_win() for all options)
    width = "auto",
    height = "auto",
    row = "auto",
    col = "auto",
    border = "double",
  },
  per_buffer_config = {
    lines = 4, -- Number of lines showed on preview.
    sort_automatically = true, -- Auto sort buffer marks.
    satellite = { -- defualt to nil, display arrow index in scrollbar at every update
      enable = false,
      overlap = true,
      priority = 1000,
    },
    treesitter_context = nil, -- it can be { line_shift_down = 2 }, currently not usable unless you try this branch:https://github.com/nvim-treesitter/nvim-treesitter-context/pull/419 which add multi-window support
  },
  separate_save_and_remove = false, -- if true, will remove the toggle and create the save/remove keymaps.
  leader_key = ";",
  save_key = "cwd", -- what will be used as root to save the bookmarks. Can be also `git_root`.
  global_bookmarks = false, -- if true, arrow will save files globally (ignores separate_by_branch)
  index_keys = "123456789zxcbnmZXVBNM,afghjklAFGHJKLwrtyuiopWRTYUIOP", -- keys mapped to bookmark index, i.e. 1st bookmark will be accessible by 1, and 12th - by c
  full_path_list = { "update_stuff" } -- filenames on this list will ALWAYS show the file path too.
}
```

You can also map previous and next key:

```lua
vim.keymap.set("n", "H", require("arrow.persist").previous)
vim.keymap.set("n", "L", require("arrow.persist").next)
vim.keymap.set("n", "<C-s>", require("arrow.persist").toggle)
```


## Statusline

You can use `require('arrow.statusline')` to access the statusline helpers:

```lua
local statusline = require('arrow.statusline')
statusline.is_on_arrow_file() -- return nil if current file is not on arrow.  Return the index if it is.
statusline.text_for_statusline() -- return the text to be shown in the statusline (the index if is on arrow or "" if not)
statusline.text_for_statusline_with_icons() -- Same, but with an bow and arrow icon ;D
```

![statusline](https://i.imgur.com/v7Rvagj.png)

## NvimTree
Show arrow marks in front of filename

<img width="343" alt="截屏2024-03-25 04 14 51" src="https://private-user-images.githubusercontent.com/97848247/318196350-7c71a880-0920-46d0-a1d4-14b72d152c5e.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MTE4MDUyMTAsIm5iZiI6MTcxMTgwNDkxMCwicGF0aCI6Ii85Nzg0ODI0Ny8zMTgxOTYzNTAtN2M3MWE4ODAtMDkyMC00NmQwLWExZDQtMTRiNzJkMTUyYzVlLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMzAlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzMwVDEzMjE1MFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTUyOTQ3OGJjN2QzM2VkYjIxNWQyMTQ0ZWI4YTAyZjlkNWMwZjdlN2FjODM3NGU1YzBmNWY2NzJhNDA3YjMyZDQmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.U1OsWMsE0WQB_kT0ZjZlcr1UD7eU1Jrz25NXOvKUmZ0">

A small patch is needed.
<details>
  <summary>Click to expand</summary>

  In `nvim-tree.lua/lua/nvim-tree/renderer/builder.lua`
change function `formate_line` to
```lua
function Builder:format_line(indent_markers, arrows, icon, name, node)
  local added_len = 0
  local function add_to_end(t1, t2)
    if not t2 then
      return
    end
    for _, v in ipairs(t2) do
      if added_len > 0 then
        table.insert(t1, { str = M.opts.renderer.icons.padding })
      end
      table.insert(t1, v)
    end

    -- first add_to_end don't need padding
    -- hence added_len is calculated at the end to be used next time
    added_len = 0
    for _, v in ipairs(t2) do
      added_len = added_len + #v.str
    end
  end

  local line = { indent_markers, arrows }
  local arrow_index = 1
  local function extractFilenames(paths)
    local filenames = {}
    for _, path in ipairs(paths) do
      local filename = path:match "([^/]+)$"
      table.insert(filenames, filename)
    end
    return filenames
  end
  local arrow_filenames = vim.g.arrow_filenames
  if arrow_filenames then
    local extracted_arrow_filenames = extractFilenames(arrow_filenames)
    for i, filename in ipairs(extracted_arrow_filenames) do
      if filename == node.name then
        local statusline = require "arrow.statusline"
        arrow_index = statusline.text_for_statusline(i)
        line[1].str = string.sub(line[1].str, 1, -3)
        line[2].str = "(" .. arrow_index .. ") "
        line[2].hl = { "ArrowFileIndex" }
        break
      end
    end
  end

  add_to_end(line, { icon })

  for i = #M.decorators, 1, -1 do
    add_to_end(line, M.decorators[i]:icons_before(node))
  end

  add_to_end(line, { name })

  for i = #M.decorators, 1, -1 do
    add_to_end(line, M.decorators[i]:icons_after(node))
  end

  return line
end
```

</details>

## Highlights

- ArrowFileIndex
- ArrowCurrentFile
- ArrowAction
- ArrowDeleteMode

## Working with sessions plugins

If you have any error using arrow with a session plugin,
like on mini.sessions, add this to the post load session hook:

```lua
require("arrow.git").refresh_git_branch() -- only if separated_by_branch is true
require("arrow.persist").load_cache_file()
```

Obs: persistence.nvim works fine with arrow.

## Special Contributors

- ![xzbdmw](https://github.com/xzbdmw) - Had the idea of per buffer bookmarks and
helped me to implement it.

### Do you like my work? Please, buy me a coffee

https://www.buymeacoffee.com/otavioschwanck
