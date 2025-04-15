require("auto-session").setup({
	pre_save_cmds = {
		-- Close current git diffview since it won't get reloaded correctly
		"DiffviewClose",
	},
})

-- suggested by auto-session
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
