require("auto-session").setup({
	auto_restore = false, -- manual restore
	purge_after_minutes = 2 * 24 * 60, -- 2 days
	pre_save_cmds = {
		-- Close current git diffview since it won't get reloaded correctly
		"DiffviewClose",

		-- Not useful anyway, it doesn't resume automatically.
		"ClaudeCodeClose",
	},
})

-- suggested by auto-session
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

vim.keymap.set("n", "<Leader>ql", ":AutoSession restore<CR>", { silent = true, desc = "Restore last session" })
vim.keymap.set("n", "<Leader>qL", ":AutoSession search<CR>", { silent = true, desc = "Search a session to restore" })
