-- Register the tree-sitter parser on startup
-- This ensures that nvim-treesitter can find the parser config
-- even if require('m2').setup() hasn't been called yet.

vim.filetype.add({
  extension = {
    m2 = 'macaulay2',
  },
})

require"m2_ts".setup()

require"m2_shell".setup()

