local M = {}

---@class M2Opts
---@field install? boolean Install missing dependencies automatically (default true).
---@field parser? boolean Install the released parser and queries (default true).
---@field lsp? boolean|vim.lsp.Config Enable m2-ls; a table overrides its configuration.
---@field term? boolean|M2TermOpts Enable the terminal helper; a table overrides its options.

local options
local setup_pending = false

---@param opts? M2Opts
function M.setup(opts)
  options = vim.tbl_deep_extend("force", {
    install = true,
    parser = true,
    lsp = true,
    term = true,
  }, opts or {})
  M._configured = true

  vim.filetype.add({ extension = { m2 = "macaulay2" } })
  if options.parser then
    require("m2.install").load_parser()
  end
  require("m2.highlight").setup()
  if options.term then
    require("m2_term").setup(type(options.term) == "table" and options.term or {})
  end

  vim.api.nvim_create_user_command("M2Install", function()
    require("m2.install").setup(vim.tbl_extend("force", options, { install = true }))
  end, { desc = "Install the Macaulay2 parser and language server", force = true })

  -- Use the final options after startup plugin and user configuration have run.
  if not setup_pending then
    setup_pending = true
    vim.schedule(function()
      setup_pending = false
      require("m2.install").setup(options)
    end)
  end
end

return M
