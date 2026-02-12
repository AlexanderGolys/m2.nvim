# m2.nvim

Macaulay2 support for Neovim, featuring Tree-sitter integration and a REPL.

## Features

- **Filetype Detection**: Automatically identifies `.m2` files.
- **Tree-sitter**: Syntax highlighting, folding, and indentation via [tree-sitter-macaulay2](https://github.com/AlexanderGolys/tree-sitter-macaulay2).
- **REPL Integration**: Send code directly from your buffer to a running Macaulay2 process.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "your-username/m2.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("m2").setup({
      repl_cmd = "M2", -- Command to start Macaulay2
      repl_split = "vsplit", -- "vsplit", "split", or "tabnew"
    })
  end,
}
```

## Usage

### Commands

- `:M2Toggle`: Start or toggle the Macaulay2 REPL window.
- `:M2SendLine`: Send the current line to the REPL.
- `:M2SendSelection`: Send the visually selected text to the REPL.

### Suggested Keybindings


```lua
vim.keymap.set("n", "<leader>mt", ":M2Toggle<CR>", { desc = "Toggle M2 REPL" })
vim.keymap.set("n", "<leader>ms", ":M2SendLine<CR>", { desc = "Send line to M2" })
vim.keymap.set("v", "<leader>ms", ":M2SendSelection<CR>", { desc = "Send selection to M2" })
```

## License

MIT
