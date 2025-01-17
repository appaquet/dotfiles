
-----------
-- copilot
-- https://github.com/zbirenbaum/copilot.lua
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


-----------
--- avante
--- https://github.com/yetone/avante.nvim
require('avante_lib').load()
require('avante').setup ({
  -- From https://github.com/yetone/avante.nvim/blob/main/lua/avante/config.lua
  provider = "copilot",
  auto_suggestions_provider = "copilot",
})

-- needed for avante
require('render-markdown').setup ({
  file_types = { "markdown", "Avante" },
})

