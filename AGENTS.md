# Agents Guide for m2.nvim

Purpose
- This repository is a Neovim plugin that provides Macaulay2 filetype support, tree-sitter queries, and REPL integration.
- This file tells agentic tools how to build, lint, test, and follow local coding style.

Repository layout
- `plugin/m2.lua` registers filetype, tree-sitter, and REPL setup at startup.
- `lua/m2/init.lua` is the public setup entry point for the newer API.
- `lua/m2/repl.lua` implements a basic terminal REPL toggle and send helpers.
- `lua/m2_shell.lua` implements a more advanced REPL with cell execution and highlighting.
- `lua/m2_ts.lua` registers the `macaulay2` tree-sitter parser.
- `ftdetect/macaulay2.lua` adds `.m2` filetype detection.
- `queries/macaulay2/*.scm` contains tree-sitter highlight, indent, fold, and tag queries.

Cursor / Copilot rules
- No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` files found.

Build, lint, test commands
- Build: not applicable (pure Lua Neovim plugin; no build step detected).
- Lint: no lint configuration detected.
- Test: no automated test runner detected.
- Single test: not applicable.

Manual validation (use when changing behavior)
- Launch Neovim with this plugin on `runtimepath` (e.g., via your plugin manager).
- Open a `.m2` file and check filetype: `:set filetype?` should be `macaulay2`.
- Verify tree-sitter is active: `:TSInstall maculay2` (if needed), then open file and inspect highlights.
- Run REPL commands and confirm behavior:
  - `:M2Toggle` then `:M2SendLine` / `:M2SendSelection` for `lua/m2/repl.lua`.
  - `:M2Start`, `:M2SendCell`, `:M2Clear`, `:M2Stop` for `lua/m2_shell.lua`.
- Ensure the `M2` executable is available in PATH for REPL features.

Quick dev commands (optional)
- Start a clean Neovim with this repo on `runtimepath`:
  - `nvim --clean -u NONE "+set rtp+=/home/flux/nvim-plugins/m2.nvim" "+lua require('m2').setup()"`.
- Verify filetype detection quickly:
  - `nvim --clean -u NONE "+set rtp+=/home/flux/nvim-plugins/m2.nvim" "+e test.m2" "+set filetype?"`.
- If tree-sitter is missing locally, install it from Neovim:
  - `:TSInstall maculay2`.

Public API surface (keep stable)
- `require("m2").setup(opts)` in `lua/m2/init.lua`.
  - `opts.repl_cmd` (string) default `"M2"`.
  - `opts.repl_split` (string) one of `"vsplit" | "split" | "tabnew"`.
- `require("m2.repl").toggle(opts)` in `lua/m2/repl.lua`.
  - `opts.cmd` (string) defaults to `"M2"`.
  - `opts.split` (string) defaults to `"vsplit"`.
- `require("m2_shell").setup()` registers `:M2Start`, `:M2Stop`, `:M2SendCell`, `:M2Clear`.

Behavior notes
- `plugin/m2.lua` runs on startup and registers filetype + tree-sitter config + `m2_shell` commands.
- `lua/m2/init.lua` is opt-in and registers `:M2Toggle` / `:M2SendLine` / `:M2SendSelection`.
- The shell REPL uses a dedicated `[M2 REPL]` buffer with `buftype = "nofile"`.
- REPL job callbacks run through `vim.schedule`; keep UI updates scheduled.

Coding style (Lua)
- Prefer short, readable functions over heavy abstraction.
- Keep module structure consistent: `local M = {}` at top, `return M` at end.
- Use local helpers for internal logic; keep public API on `M`.
- Follow existing indentation in each file:
  - 2-space indent in `lua/m2/*.lua`, `plugin/m2.lua`, and `ftdetect/macaulay2.lua`.
  - 4-space indent in `lua/m2_shell.lua`.
  - Do not reformat existing files to a different indent width.
- Keep line endings LF and avoid trailing whitespace.

Imports and module boundaries
- Use `require("...")` with module-style paths, e.g. `require("m2.repl")`.
- Avoid circular dependencies; prefer wiring from `plugin/m2.lua` and `lua/m2/init.lua`.
- When adding new modules, place them under `lua/m2/` and expose through `lua/m2/init.lua`.

Formatting conventions
- Prefer double quotes for strings in new Lua code unless the file already uses single quotes.
- Use trailing commas for multi-line tables when it improves diffs.
- Align tables and arguments minimally; avoid manual column alignment.

Type annotations and docs
- This repo uses EmmyLua annotations for public types and params.
- Use these tags where helpful: `---@class`, `---@field`, `---@param`, `---@return`.
- Keep annotations close to the functions or tables they describe.

Naming conventions
- Functions and locals: `snake_case`.
- Module tables: `M`.
- User-facing commands use `M2*` naming (`M2Toggle`, `M2SendLine`, etc.).
- Prefer explicit names over abbreviations unless the name is already established.

Error handling and user feedback
- Use early returns for guard conditions.
- For optional dependencies (tree-sitter parser), wrap in `pcall` and exit gracefully.
- Use `vim.notify` with an appropriate `vim.log.levels.*` for user-facing errors or info.

Neovim API usage
- Prefer `vim.api` for buffer/window operations.
- Use `vim.api.nvim_set_option_value` instead of deprecated `vim.api.nvim_buf_set_option`.
- Use `vim.keymap.set` for mappings and pass `desc` for user clarity.
- Prefer buffer-local mappings for REPL interactions.
- Use `vim.bo[buf].*` for buffer-local options where appropriate.

Keymaps and commands
- `lua/m2_shell.lua` defines buffer-local `<leader>m*` mappings on `FileType`.
- Keep keymaps behind user commands; do not hardcode global mappings.
- Always provide `desc` for discoverability.
- Avoid remapping `<CR>` outside the REPL output buffer.

Tree-sitter query files (`queries/macaulay2/*.scm`)
- Use `;` for comments in `.scm` files.
- Keep patterns grouped by feature (comments, literals, operators, etc.).
- Add new captures consistent with existing `@` groups and naming.

Query change checklist
- Prefer minimal pattern edits over sweeping capture changes.
- Keep captures stable to avoid unexpected highlight changes.
- Add comments when introducing non-obvious query logic.
- Validate by opening a `.m2` file with tree-sitter enabled.

Filetype detection
- Extend `ftdetect/macaulay2.lua` only if new extensions are supported.
- Keep `plugin/m2.lua` and `ftdetect/macaulay2.lua` consistent with filetype naming.

Dependencies and assumptions
- Neovim 0.9+ (uses `vim.api.nvim_set_option_value`).
- `nvim-treesitter` installed for parser integration.
- `tree-sitter-macaulay2` repository for the parser.
- Macaulay2 binary `M2` available for REPL features.

Adding new files
- New Lua modules go under `lua/m2/` and should be required from `lua/m2/init.lua` when public.
- Tree-sitter queries belong under `queries/macaulay2/` with `.scm` extension.
- Keep filenames lowercase and consistent with existing naming.
- Avoid adding empty placeholder files unless they are part of a deliberate API surface.
- If you add commands or options, document them in `README.md`.
- Keep `plugin/m2.lua` minimal; it should only wire startup behavior.

Documentation updates
- Update `README.md` when adding new commands or options.
- Keep command names and setup options in the README in sync with code.
- Mention external dependencies (`nvim-treesitter`, `M2`) if adding new ones.

Asynchronous/job patterns
- Use `vim.fn.jobstart` or `vim.fn.termopen` for REPL processes.
- Schedule buffer updates from callbacks with `vim.schedule`.
- Clean up buffers/windows on exit to avoid stale handles.

When unsure
- Check existing patterns in `lua/m2/repl.lua` and `lua/m2_shell.lua` and match their style.
- Avoid introducing new runtime dependencies unless necessary.
- Prefer minimal, direct changes over refactors.
