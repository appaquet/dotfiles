
-- Neotest
-- https://github.com/nvim-neotest/neotest
local Neotest = require("neotest")
Neotest.setup({
  adapters = {
    require("neotest-golang")({
      go_test_args = {
        "-v",
        "-count=1",
        "-timeout=10s",
      },
    }),

    require('rustaceanvim.neotest')
  },
})

local function run_nearest()
  Neotest.output_panel.open()
  Neotest.output_panel.clear()
  Neotest.run.run()
end

local function debug_nearest()
  Neotest.run.run({ strategy = "dap" })
end

local function run_file()
  Neotest.output_panel.open()
  Neotest.output_panel.clear()
  Neotest.run.run(vim.fn.expand("%"))
end

local function debug_file()
  Neotest.output_panel.open()
  Neotest.output_panel.clear()
  Neotest.run.run({ vim.fn.expand("%"), strategy = "dap" })
end

local function run_last()
  Neotest.output_panel.open()
  Neotest.output_panel.clear()
  Neotest.run.run_last()
end

local function debug_last()
  Neotest.run.run_last({ strategy = "dap" })
end

vim.keymap.set("n", "<leader>tc", run_nearest, { desc = "Test: Run nearest / under cursor" })
vim.keymap.set("n", "<leader>tdc", debug_nearest, { desc = "Test: Debug nearest" })
vim.keymap.set("n", "<leader>tf", run_file, { desc = "Test: Run file" })
vim.keymap.set("n", "<leader>tdf", debug_file, { desc = "Test: Debug file" })
vim.keymap.set("n", "<leader>tl", run_last, { desc = "Test: Run last" })
vim.keymap.set("n", "<leader>tdl", debug_last, { desc = "Test: Debug last" })
vim.keymap.set("n", "<leader>ts", Neotest.run.stop, { desc = "Test: Stop" })

vim.keymap.set("n", "<leader>to", Neotest.output_panel.open, { desc = "Test: Open output panel" })
vim.keymap.set("n", "<leader>tk", Neotest.output_panel.clear, { desc = "Test: Clear output panel" })
vim.keymap.set("n", "<leader>tq", Neotest.output_panel.close, { desc = "Test: Close output panel" })
