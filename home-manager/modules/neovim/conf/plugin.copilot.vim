lua << END

-- copilot (https://github.com/zbirenbaum/copilot.lua)
require("copilot").setup({
  suggestion = { enabled = false },
  panel = { enabled = false },

  filetypes = {
    markdown = true, -- overrides default
  }
})

-- https://github.com/zbirenbaum/copilot-cmp
require("copilot_cmp").setup {
  method = "getCompletionsCycling",
}

END
