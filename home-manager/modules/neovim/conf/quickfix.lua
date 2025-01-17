
-- Quickfix
vim.keymap.set("n", "<leader>xo", "<cmd>copen<cr>", { desc = "Quickfix: Open" })
vim.keymap.set("n", "<leader>xq", "<cmd>cclose<cr>", { desc = "Quickfix: Close" })
vim.keymap.set("n", "<leader>xn", "<cmd>cnext<cr>", { desc = "Quickfix: Next" })
vim.keymap.set("n", "[x", "<cmd>cprev<cr>", { desc = "Quickfix: Prev" })
vim.keymap.set("n", "]x", "<cmd>cnext<cr>", { desc = "Quickfix: Next" })
vim.keymap.set("n", "<leader>xp", "<cmd>cprev<cr>", { desc = "Quickfix: Previous" })
