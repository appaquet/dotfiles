lua << END

-- copilot (https://github.com/zbirenbaum/copilot.lua)
-- disable suggestions & panel since we are using cmp
require("copilot").setup({
  suggestion = { enabled = false }, -- because we use cmp
  panel = { enabled = false }, -- because we use cmp

  filetypes = {
   -- overrides defaults
    markdown = true,
    yaml = true,
  }
})

-- https://github.com/zbirenbaum/copilot-cmp
require("copilot_cmp").setup {
  method = "getCompletionsCycling",
}

END
