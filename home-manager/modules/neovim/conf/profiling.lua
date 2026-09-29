require("which-key").add({
	{ "<leader>P", group = "Profiler" },
})

-- The profiler replaces module functions with wrapper closures; luv re-creates a work function in
-- its worker thread without upvalues, so a wrapped function handed to vim.uv.new_work fails there.
-- auto-session passes Lib.purge_old_sessions to a worker to purge old sessions (see sessions.lua).
require("snacks").setup({
	profiler = {
		filter_fn = {
			["auto-session.lib.purge_old_sessions"] = false,
		},
	},
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
