# arrow.nvim

Arrow.nvim is a plugin made to manage quick file bookmarks using a single UI. You can just map one
key and have everything you need to get started.

![arrow.nvim](https://i.imgur.com/mPdSC5s.png)
![arrow.nvim_gif](https://i.imgur.com/LcvG406.gif)

## Installation

### Lazy

```lua
return {
  "otavioschwanck/arrow.nvim",
  opts = {
    show_icons = true,
    leader_key = ';' -- Recommended to be a single key
  }
}
```

### Packer

```lua
use { 'otavioschwanck/arrow.nvim', config = function()
  require('arrow').setup({
    show_icons = true,
    leader_key = ';' -- Recommended to be a single key
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
  }
  separate_save_and_remove = false, -- if true, will remove the toggle and create the save/remove keymaps.
  leader_key = ";",
  global_bookmarks = false, -- if true, arrow will save files globally (ignores separate_by_branch)
  index_keys = "123456789zxcbnmZXVBNM,afghjklAFGHJKLwrtyuiopWRTYUIOP", -- keys mapped to bookmark index, i.e. 1st bookmark will be accessible by 1, and 12th - by c
  full_path_list = { "update_stuff" } -- filenames on this list will ALWAYS show the file path too.
  fix_cursor = false, -- if true, arrow will execute ":Esc" to reset the cursor after closing menu
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

## Highlights

- ArrowFileIndex
- ArrowCurrentFile
- ArrowAction
- ArrowDeleteMode

## Working with sessions plugins

If you have any error using arrow with a session plugin, like on mini.sessions, add this to the post load session hook:

```lua
require("arrow.git").refresh_git_branch() -- only if separated_by_branch is true
require("arrow.persist").load_cache_file()
```

Obs: persistence.nvim works fine with arrow.

### Do you like my work? Please, buy me a coffee

https://www.buymeacoffee.com/otavioschwanck
