require("which-key").add({
	{ "<leader>a", group = "Avante" },
})

-- avante
-- https://github.com/yetone/avante.nvim
require("avante_lib").load()
require("avante").setup({
	-- From https://github.com/yetone/avante.nvim/blob/main/lua/avante/config.lua
	provider = "copilot",

	behaviour = {
		auto_suggestions = false, -- I use copilot.lua
		use_cwd_as_project_root = true, -- Fix invalid path if inside sub-directory
	},

	providers = {
		claude = {
			model = "claude-sonnet-4-20250514",
		},
		copilot = {
			model = "gpt-4.1",
		},
	},

	hints = { enabled = false }, -- Keymap hints, we know how to use it now, no need...

	web_search_engine = {
		provider = "tavily",
	},

	-- For MCPHub integration
	-- https://ravitemer.github.io/mcphub.nvim/extensions/avante.html
	system_prompt = function()
		local hub = require("mcphub").get_hub_instance()
		return hub and hub:get_active_servers_prompt() or ""
	end,
	custom_tools = function()
		return {
			require("mcphub.extensions.avante").mcp_tool(),
		}
	end,
})

-- codecompanion
-- https://codecompanion.olimorris.dev/getting-started.html
require("codecompanion").setup({
	strategies = {
		chat = {
			adapter = "copilot",
			model = "gpt-4.1",
		},
		inline = {
			adapter = "copilot",
			model = "gpt-4.1",
		},
	},
})
vim.keymap.set(
	"v",
	"gs",
	":'<,'>CodeCompanion Fix any spelling or unclear text in this selected text. Try to keep the original meaning and intent of the text.<CR>",
	{ silent = true, desc = "CodeCompanion: Fix spelling & unclear text" }
)

-- MCPHub
require("mcphub").setup({})
vim.keymap.set("n", "<Leader>au", ":<CR>:MCPHub<CR>", { silent = true, desc = "Open MCPHub" })
