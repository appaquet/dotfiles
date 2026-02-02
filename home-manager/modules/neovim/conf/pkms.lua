require("which-key").add({
	{ "<leader>m", group = "PKMS" },
	{ "<leader>mj", group = "Journal" },
})

-- markdown oxide lsp configuration
-- https://oxide.md/Setup+Instructions
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("MarkdownOxideConfig", {}),
	callback = function(ev)
		-- Code lens support
		local function codelens_supported(bufnr)
			for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
				if c.server_capabilities and c.server_capabilities.codeLensProvider then
					return true
				end
			end
			return false
		end

		vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "CursorHold", "BufEnter" }, {
			buffer = ev.buf,
			callback = function()
				if codelens_supported(ev.buf) then
					vim.lsp.codelens.refresh({ bufnr = ev.buf })
				end
			end,
		})

		if codelens_supported(ev.buf) then
			vim.lsp.codelens.refresh({ bufnr = ev.buf })
		end

		-- Markdown Oxide daily note command
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client.name == "markdown_oxide" then
			vim.api.nvim_create_user_command("Daily", function(args)
				client:request("workspace/executeCommand", { command = "jump", arguments = { args.args } }, nil, ev.buf)
			end, { desc = "Open daily note", nargs = "*" })
		end
	end,
})

vim.keymap.set("n", "<leader>mjd", ":Daily today<CR>", { silent = true, desc = "PKMS: Open today's note" })
vim.keymap.set("n", "<leader>mjy", ":Daily yesterday<CR>", { silent = true, desc = "PKMS: Open yesterday's note" })
vim.keymap.set("n", "<leader>mjt", ":Daily tomorrow<CR>", { silent = true, desc = "PKMS: Open tomorrow's note" })
