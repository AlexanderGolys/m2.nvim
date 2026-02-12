local M = {}

---@class M2Opts
---@field repl_cmd? string
---@field repl_split? "vsplit" | "split" | "tabnew"

---Default options
local default_opts = {
  repl_cmd = "M2",
  repl_split = "vsplit",
}

---@type M2Opts
M.opts = {}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", default_opts, opts or {})

  -- Register tree-sitter parser
  require("m2.treesitter").setup()

  -- Register commands
  vim.api.nvim_create_user_command("M2Toggle", function()
    require("m2.repl").toggle({
      cmd = M.opts.repl_cmd,
      split = M.opts.repl_split,
    })
  end, { desc = "Toggle Macaulay2 REPL" })

  vim.api.nvim_create_user_command("M2SendLine", function()
    require("m2.repl").send_line()
  end, { desc = "Send current line to Macaulay2 REPL" })

  vim.api.nvim_create_user_command("M2SendSelection", function()
    require("m2.repl").send_selection()
  end, { desc = "Send selection to Macaulay2 REPL", range = true })

  -- Default keymaps (optional, maybe leave to user?)
  -- For now, just provide the commands.
end

return M
