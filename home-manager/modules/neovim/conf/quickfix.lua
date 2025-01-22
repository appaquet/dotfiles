
-- Quickfix
vim.keymap.set("n", "<leader>ko", "<cmd>copen<cr>", { desc = "Quickfix: Open" })
vim.keymap.set("n", "<leader>kq", "<cmd>cclose<cr>", { desc = "Quickfix: Close" })
vim.keymap.set("n", "<leader>kn", "<cmd>cnext<cr>", { desc = "Quickfix: Next" })
vim.keymap.set("n", "[k", "<cmd>cprev<cr>", { desc = "Quickfix: Prev" })
vim.keymap.set("n", "]k", "<cmd>cnext<cr>", { desc = "Quickfix: Next" })
vim.keymap.set("n", "<leader>kp", "<cmd>cprev<cr>", { desc = "Quickfix: Previous" })
