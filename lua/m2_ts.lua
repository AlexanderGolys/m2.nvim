local M = {}

function M.setup()
  local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

  parser_config.macaulay2 = {
    install_info = {
      url = "https://github.com/AlexanderGolys/tree-sitter-macaulay2",
      files = { "src/parser.c", "src/scanner.c" },
      branch = "main",
    },
    filetype = "macaulay2",
  }

  -- Register the filetype mapping for tree-sitter
  vim.treesitter.language.register("macaulay2", "macaulay2")
end

return M
