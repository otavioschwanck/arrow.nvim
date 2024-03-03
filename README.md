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

## Commands Module

### Overview

The `commands` module in Arrow is designed to facilitate custom command creation and handling within Neovim. It provides a simple yet powerful interface for defining and executing commands, leveraging Neovim's API and Arrow's custom UI components.

### Defining Commands

Commands are defined in the M.commands table. Each command is a key-value pair where the key is the command's name, and the value is a function that encapsulates the command's logic.

```lua
M.commands = {
  open = function ()
    ui.openMenu()
  end,
}
```
### Executing commands

```lua
:Arrow open
```
This would invoke the `open` command defined earlier, executing its associated function.

### Command Parsing
The `M.parse` function is used to parse the command line arguments provided to the `Arrow` command. It separates the command's name from any additional arguments, allowing for more complex command handling.

### Error Handling
The `M.error` function is used to display error messages, for instance, when an unknown command is invoked. It leverages Neovim's `vim.notify` function to display error messages with an appropriate log level.

### Extending Commands
To add new commands, simply extend the `M.commands` table with new key-value pairs. Each new command should have a unique name and an associated function that defines its behavior.

### Completion
The `complete` function provides custom tab completion for the `Arrow` command, suggesting available command names based on the current input. This enhances the user experience by making it easier to discover and execute commands.

### Summary
The `commands` module in Arrow offers a flexible and intuitive way to define and manage custom commands in Neovim. By encapsulating command logic in standalone functions and providing built-in parsing, error handling, and completion, it streamlines the development of command-driven features within the plugin.





### Do you like my work? Please, buy me a coffee

https://www.buymeacoffee.com/otavioschwanck
