
-----------
-- copilot
-- https://github.com/zbirenbaum/copilot.lua
require("copilot").setup({
  suggestion = { enabled = false }, -- because we use cmp
  panel = { enabled = false }, -- because we use cmp
  copilot_model = "gpt-4o-copilot",

  filetypes = {
   -- overrides defaults
    markdown = true,
    yaml = true,
  }
})

-- https://github.com/zbirenbaum/copilot-cmp
-- FIXME: but overriden with https://github.com/litoj/cmp-copilot
require("cmp_copilot").setup { -- FIXME: Overriden (see ../default.nix), originally "copilot_cmp"
  method = "getCompletionsCycling",
}

-----------
--- avante
--- https://github.com/yetone/avante.nvim
require('avante_lib').load()
require('avante').setup ({
  -- From https://github.com/yetone/avante.nvim/blob/main/lua/avante/config.lua
  provider = "copilot",

  -- Not using auto suggestion for now
  -- https://github.com/yetone/avante.nvim/issues/1047
  auto_suggestions_provider = "copilot", -- not used
  behaviour = {
    auto_suggestions = false, -- Experimental stage
  }
})

-- needed for avante
require('render-markdown').setup ({
  file_types = { "markdown", "Avante" },
})

