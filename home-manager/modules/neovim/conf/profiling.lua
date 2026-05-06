require("which-key").add({
	{ "<leader>P", group = "Profiler" },
})

-- https://github.com/folke/snacks.nvim/blob/main/docs/profiler.md
local Snacks = require("snacks")
Snacks.toggle.profiler():map("<leader>Pt") -- toggle profiler
Snacks.toggle.profiler_highlights():map("<leader>Ph") -- toggle highlights

if vim.env.PROF then
	local profiler = require("snacks.profiler")
	profiler.startup({
		startup = {
			event = "VimEnter", -- stop profiler on this event. Defaults to `VimEnter`
			-- event = "UIEnter",
			-- event = "VeryLazy",
		},
	})
end
