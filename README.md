# m2.nvim

Set up [Macaulay2](https://macaulay2.com) editing on a new device with one
Neovim plugin: filetype detection, Tree-sitter highlighting, and a configured
[m2-ls](https://github.com/AlexanderGolys/m2-ls) language server.

## Installation

Requires Neovim 0.11+, Git, a C compiler, the `tree-sitter` CLI, and Rust/Cargo
(Rust 1.88+ for m2-ls). Install the CLI with your package manager or
`cargo install --locked tree-sitter-cli`. Install Macaulay2 separately if you
want to evaluate code using the terminal helper.

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "AlexanderGolys/m2.nvim",
  version = "*",
  lazy = false,
  opts = {},
}
```

On startup, the plugin installs missing dependencies asynchronously:

- Downloads the released `v6.3.2` parser from
  [tree-sitter-macaulay2](https://github.com/AlexanderGolys/tree-sitter-macaulay2),
  builds it with `tree-sitter build`, and installs the matching queries.
- Reuses `m2-ls` from your PATH, or installs the released crate using
  `cargo install --locked --root <data-directory>/m2.nvim/cargo m2-ls`.
- Enables `m2_ls` through Neovim's built-in LSP configuration for `.m2` files,
  including standalone files. Project roots use `.git` when available.

Installed files live under `stdpath("data")/m2.nvim`, outside the plugin
checkout. Subsequent startups reuse them without downloading again.
Highlighting and LSP activation begin when installation finishes, including
for already open Macaulay2 buffers. Use `:M2Install` to retry a failed install.
Errors are shown in `:messages`. A pre-existing m2-ls is reused without updates;
update it with the same tool that installed it.

The plugin manages its parser and queries directly; `nvim-treesitter` is not
required. Disable any separate `m2_ls` setup to avoid starting duplicate clients.

## Configuration

```lua
require("m2").setup({
  install = true, -- Automatically install missing dependencies.
  parser = true, -- Install and load the released parser and queries.
  lsp = {
    settings = {
      ["m2-ls"] = {
        formatting = { indent = 4 },
        inlayHints = { expressionTypes = true },
      },
    },
  },
  term = true, -- Enable commands for a real Macaulay2 terminal.
})
```

`lsp` defaults to `true`; a table accepts Neovim LSP configuration overrides,
including `cmd`, `capabilities`, `on_attach`, and `settings`. A custom `cmd`
skips Cargo installation. Set `lsp = false` to disable the server, or
`parser = false` to manage the parser yourself. `install = false` suppresses
automatic downloads while using installed dependencies; `:M2Install` explicitly
installs missing enabled dependencies. The former local-checkout `parser`
option has been replaced by this boolean option.

### Highlighting

The plugin starts Tree-sitter highlighting in Macaulay2 and Markdown buffers.
Fenced code blocks accept `macaulay2` and `m2`, including LSP hover windows.
For Markdown, install the `markdown` and `markdown_inline` parsers separately
using your preferred parser manager. Missing parsers are skipped.

Semantic highlight defaults cover all m2-ls types and modifiers through
`@lsp.type.*.macaulay2`, `@lsp.mod.*.macaulay2`, and
`@lsp.typemod.*.*.macaulay2`. Namespaces are italic; decorators link to `@type`.
`strong`, `emphasis`, and `link` modifiers add bold, italic, and underline.
Other modifiers preserve the token style. Defaults are restored after
colorscheme changes; override them with `vim.api.nvim_set_hl`.

## Terminal helper

The helper runs the installed `M2` executable in a split and sends source text
to it. Set `term = false` to disable it.

| Command | Default mapping | Action |
| --- | --- | --- |
| `:M2TermOpen` | `<leader>mo` | Open or focus the terminal. |
| `:M2TermToggle` | `<leader>mt` | Hide or show it, keeping M2 running. |
| `:M2TermClose` | `<leader>mq` | Quit M2 and close the terminal. |
| `:M2TermSendCell` | `<leader>mc` | Send the Tree-sitter cell under the cursor. |
| `:M2TermSendLine` | `<leader>ml` | Send the current line. |
| `:'<,'>M2TermSend` | `<leader>mc` (visual) | Send the selection. |

Pass `term = { keys = { open = "<leader>mo" } }` to override mappings.
Set an individual entry to `false` to remove it, or `term = { keys = false }`
to keep only the commands. Available keys are `open`, `toggle`, `close`,
`send_cell`, `send_line`, and `send_visual`.

## License

MIT OR Apache-2.0. See `LICENCE` and `LICENCE-APACHE`.
