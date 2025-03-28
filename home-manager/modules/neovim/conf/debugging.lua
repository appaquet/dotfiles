-- nvim-dap
-- https://github.com/mfussenegger/nvim-dap
local dap = require("dap")
vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "DAP: Toggle breakpoint" })
vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "DAP: Start/Continue" })
vim.keymap.set("n", "<leader>dI", dap.step_into, { desc = "DAP: Step into" })
vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "DAP: Step out" })
vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "DAP: Step over" })
vim.keymap.set("n", "<leader>dj", dap.down, { desc = "DAP: Down" })
vim.keymap.set("n", "<leader>dk", dap.up, { desc = "DAP: Up" })
vim.keymap.set("n", "<leader>dp", dap.pause, { desc = "DAP: Pause" })
vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "DAP: Terminate" })
vim.keymap.set("n", "<leader>ds", dap.session, { desc = "DAP: Session" })
vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { desc = "DAP: Toggle repl" })
vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "DAP: Run last" })
vim.keymap.set("n", "<leader>dC", dap.run_to_cursor, { desc = "DAP: Run to cursor" })

-- nvim-dap-ui
-- https://github.com/rcarriga/nvim-dap-ui
local dapui = require("dapui")
dapui.setup({
	layouts = {
		{
			position = "bottom",
			size = 15,
			elements = {
				{ id = "scopes", size = 0.5 },
				{ id = "watches", size = 0.5 },
			},
		},
		{
			position = "right",
			size = 50,
			elements = {
				{ id = "repl", size = 0.1 },
				{ id = "breakpoints", size = 0.5 },
				{ id = "stacks", size = 0.4 },
			},
		},
	},
	expand_lines = false,
})
vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "DAP: Toggle UI" })
dap.listeners.before.attach.dapui_config = function()
	dapui.open()
end
dap.listeners.before.launch.dapui_config = function()
	dapui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
	dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
	dapui.close()
end

-- Per language setup
-- https://github.com/leoluz/nvim-dap-go
require("dap-go").setup()
