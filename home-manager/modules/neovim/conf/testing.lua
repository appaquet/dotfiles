require("which-key").add({
	{ "<leader>t", group = "Testing" },
})

-- Neotest
-- https://github.com/nvim-neotest/neotest
local Neotest = require("neotest")
Neotest.setup({
	adapters = {
		require("rustaceanvim.neotest"),

		require("neotest-golang")({
			go_test_args = {
				"-v",
				"-count=1",
				"-timeout=10s",
			},
		}),

		require("neotest-python"),
	},

	-- Notify on completion
	-- https://github.com/nvim-neotest/neotest/issues/218
	consumers = {
		notify = function(client)
			client.listeners.results = function(_adapter_id, results, partial)
				-- Partial results can be very frequent
				if partial then
					return
				end

				local fail_count = 0
				local success_count = 0
				for _, result in pairs(results) do
					if result.status == "failed" then
						fail_count = fail_count + 1
					else
						success_count = success_count + 1
					end
				end

				if fail_count > 0 then
					vim.notify(string.format("%d test(s) failed", fail_count), vim.log.levels.ERROR, { title = "Neotest" })
				end
				if success_count > 0 then
					vim.notify(string.format("%d test(s) passed", success_count), vim.log.levels.INFO, { title = "Neotest" })
				end
			end
			return {}
		end,
	},
})

local function run_nearest()
	Neotest.summary.open()
	Neotest.run.run()
end

local function debug_nearest()
	Neotest.run.run({ strategy = "dap" })
end

local function run_file()
	Neotest.summary.open()
	Neotest.run.run(vim.fn.expand("%"))
end

local function debug_file()
	Neotest.summary.open()
	Neotest.run.run({ vim.fn.expand("%"), strategy = "dap" })
end

local function run_dir()
	Neotest.summary.open()
	local dir = vim.fn.expand("%:p:h")
	Neotest.run.run(dir)
end

local function debug_dir()
	Neotest.summary.open()
	local dir = vim.fn.expand("%:p:h")
	Neotest.run.run({ dir, strategy = "dap" })
end

local function run_last()
	Neotest.summary.open()
	Neotest.run.run_last()
end

local function debug_last()
	Neotest.run.run_last({ strategy = "dap" })
end

vim.keymap.set("n", "<leader>tc", run_nearest, { desc = "Test: Run nearest / under cursor" })
vim.keymap.set("n", "<leader>tdc", debug_nearest, { desc = "Test: Debug nearest" })
vim.keymap.set("n", "<leader>tf", run_file, { desc = "Test: Run file" })
vim.keymap.set("n", "<leader>tdf", debug_file, { desc = "Test: Debug file" })
vim.keymap.set("n", "<leader>tp", run_dir, { desc = "Test: Run package/dir" })
vim.keymap.set("n", "<leader>tdp", debug_dir, { desc = "Test: Debug package/dir" })
vim.keymap.set("n", "<leader>tl", run_last, { desc = "Test: Run last" })
vim.keymap.set("n", "<leader>tdl", debug_last, { desc = "Test: Debug last" })
vim.keymap.set("n", "<leader>tu", Neotest.run.stop, { desc = "Test: Stop" })

vim.keymap.set("n", "<leader>ts", Neotest.summary.toggle, { desc = "Test: Toggle summary / side panel" })

vim.keymap.set("n", "<leader>to", Neotest.output_panel.toggle, { desc = "Test: Toggle output panel" })
vim.keymap.set("n", "<leader>tk", Neotest.output_panel.clear, { desc = "Test: Clear output panel" })
vim.keymap.set("n", "<leader>tq", Neotest.output_panel.close, { desc = "Test: Close output panel" })
