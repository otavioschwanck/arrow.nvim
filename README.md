# arrow.nvim

Arrow.nvim is a plugin made to manage quick file bookmarks using a single UI.  You can just map one
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
  mappings = {
		edit = "e",
		delete_mode = "d",
		clear_all_items = "C",
		toggle = "s",
		open_vertical = "v",
		open_horizontal = "-",
		quit = "q",
  },
  leader_key = ";",
  after_9_keys = "zxcbnmZXVBNM,afghjklAFGHJKLwrtyuiopWRTYUIOP", -- Please, don't pin more than 9 XD,
  save_key = function()
    return vim.loop.cwd() -- we use the cwd as the context from the bookmarks.  You can change it for anything you want.
  end,
  full_path_list = { "update_stuff" } -- filenames on this list will ALWAYS show the file path too.
}
```

You can also map previous and next key:

```lua
vim.keymap.set("n", "H", require("arrow.persist").previous)
vim.keymap.set("n", "L", require("arrow.persist").next)
```

## Statusline

You can use `require('arrow.statusline')` to access the statusline helpers:

```lua
local statusline = require('arrow.statusline')
statusline.is_on_arrow_file() -- return nil if current file is not on arrow.  Return the index if it is.
statuline.text_for_statusline() -- return the text to be shown in the statusline (the index if is on arrow or "" if not)
statuline.text_for_statusline_with_icons() -- Same, but with an bow and arrow icon ;D
```

![statusline](https://i.imgur.com/v7Rvagj.png)

### Do you like my work?  Please, buy me a coffee
https://www.buymeacoffee.com/otavioschwanck
