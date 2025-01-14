require('render-markdown').setup ({
  file_types = { "markdown", "Avante" },
})

require('avante_lib').load()
require('avante').setup ({
  -- From https://github.com/yetone/avante.nvim/blob/main/lua/avante/config.lua
  provider = "copilot",
  auto_suggestions_provider = "copilot",

  --openai = {
    --endpoint = "https://api.openai.com/v1",
    --model = "gpt-4o",
    --timeout = 30000, -- Timeout in milliseconds
    --temperature = 0,
    --max_tokens = 4096,
  --},
  --copilot = {
    --endpoint = "https://api.githubcopilot.com",
    --model = "gpt-4o-2024-08-06",
    --proxy = nil, -- [protocol://]host[:port] Use this proxy
    --allow_insecure = false, -- Allow insecure server connections
    --timeout = 30000, -- Timeout in milliseconds
    --temperature = 0,
    --max_tokens = 4096,
  --},
})
