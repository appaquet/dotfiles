require('render-markdown').setup ({
  file_types = { "markdown", "Avante" },
})

require('avante_lib').load()
require('avante').setup ({
  -- From https://github.com/yetone/avante.nvim/blob/main/lua/avante/config.lua
  provider = "copilot",
  auto_suggestions_provider = "copilot",
})
