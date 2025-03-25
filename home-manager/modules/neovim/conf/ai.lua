
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
  provider = "claude",

  -- Not using auto suggestion for now
  -- https://github.com/yetone/avante.nvim/issues/1048
  auto_suggestions_provider = "claude",
  behaviour = {
    auto_suggestions = false, -- Experimental stage
  }
})

-- needed for avante
require('render-markdown').setup ({
  file_types = { "markdown", "Avante" },
})

