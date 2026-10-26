local M = {}

-- LSP names from the m2-ls semantic-token legend.
local semantic_types = {
  type = "@type",
  ["function"] = "@function",
  variable = "@variable",
  parameter = "@variable.parameter",
  property = "@property",
  namespace = "@module",
  enumMember = "@constant",
  keyword = "@keyword",
  string = "@string",
  number = "@number",
  operator = "@operator",
  comment = "@comment",
  method = "@function.method",
  modifier = "@keyword.modifier",
  typeParameter = "@type",
  macro = "@function.macro",
  decorator = "@type",
}

local semantic_modifiers = {
  option = {},
  file = {},
  declaration = {},
  unresolved = {},
  defaultLibrary = {},
  mutable = {},
  documentation = {},
  command = {},
  algebraic = {},
  strong = { bold = true },
  emphasis = { italic = true },
  monospace = {},
  link = { underline = true },
  math = {},
  example = {},
  test = {},
}

local function create_semantic_highlights()
  for token_type, link in pairs(semantic_types) do
    local attributes = { link = link, default = true }
    if token_type == "namespace" then
      attributes = vim.api.nvim_get_hl(0, { name = link, link = false })
      attributes.italic = true
      attributes.default = true
    end
    vim.api.nvim_set_hl(0, "@lsp.type." .. token_type .. ".macaulay2", attributes)
  end

  for modifier, style in pairs(semantic_modifiers) do
    local group = "@lsp.mod." .. modifier .. ".macaulay2"
    vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", style, { default = true }))
    for token_type in pairs(semantic_types) do
      vim.api.nvim_set_hl(0, "@lsp.typemod." .. token_type .. "." .. modifier .. ".macaulay2", {
        link = group,
        default = true,
      })
    end
  end
end

--- Enable source and Markdown highlighting when the required parsers are installed.
function M.setup()
  local group = vim.api.nvim_create_augroup("M2Highlight", { clear = true })
  create_semantic_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = create_semantic_highlights,
    desc = "Restore Macaulay2 semantic highlight defaults",
  })
  vim.treesitter.language.register("macaulay2", { "macaulay2", "m2" })

  local function start_highlighting(buffer)
    local filetype = vim.bo[buffer].filetype
    if filetype == "markdown" or filetype == "macaulay2" then
      pcall(vim.treesitter.start, buffer)
    end
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "markdown", "macaulay2" },
    callback = function(event)
      start_highlighting(event.buf)
    end,
    desc = "Highlight Macaulay2 source and Markdown code fences",
  })

  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      start_highlighting(buffer)
    end
  end
end

return M
