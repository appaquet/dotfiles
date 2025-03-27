-----------
-- LSP
-- https://github.com/neovim/nvim-lspconfig
local lspconfig = require("lspconfig")
lspconfig.pyright.setup({})
lspconfig.ts_ls.setup({})
lspconfig.marksman.setup({})
lspconfig.nixd.setup({})
lspconfig.buf_ls.setup({})
lspconfig.bashls.setup({})
--lspconfig.gopls.setup {} -- Loaded by go.nvim (see bellow)
--lspconfig.rust_analyzer.setup {} -- Loaded by rustaceanvim (see bellow)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		-- Enable completion triggered by <c-x><c-o>
		vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

		-- Buffer local mappings.
		-- See `:help vim.lsp.*` for documentation on any of the below functions
		-- Adapted a bit from https://lsp-zero.netlify.app/docs/language-server-configuration.html
		local opts = { buffer = ev.buf }
		vim.keymap.set(
			"n",
			"<leader>lgD",
			vim.lsp.buf.declaration,
			{ buffer = ev.buf, desc = "LSP: Go to declaration" }
		)
		vim.keymap.set("n", "<leader>lgd", vim.lsp.buf.definition, { buffer = ev.buf, desc = "LSP: Go to definition" })
		vim.keymap.set(
			"n",
			"<leader>lgt",
			vim.lsp.buf.type_definition,
			{ buffer = ev.buf, desc = "LSP: Go to type definition" }
		)
		vim.keymap.set(
			"n",
			"<leader>lli",
			vim.lsp.buf.implementation,
			{ buffer = ev.buf, desc = "LSP: List all implementations" }
		)
		vim.keymap.set("n", "<leader>llr", vim.lsp.buf.references, { buffer = ev.buf, desc = "LSP: List references" })
		vim.keymap.set(
			"n",
			"<leader>li",
			vim.lsp.buf.hover,
			{ buffer = ev.buf, desc = "LSP: Displays hover information about a symbol" }
		)
		vim.keymap.set(
			"n",
			"<leader>ls",
			vim.lsp.buf.signature_help,
			{ buffer = ev.buf, desc = "LSP: Show signature help" }
		)
		vim.keymap.set(
			"n",
			"<leader>lwa",
			vim.lsp.buf.add_workspace_folder,
			{ buffer = ev.buf, desc = "LSP: Add workspace folder" }
		)
		vim.keymap.set(
			"n",
			"<leader>lwr",
			vim.lsp.buf.remove_workspace_folder,
			{ buffer = ev.buf, desc = "LSP: Remove workspace folder" }
		)
		vim.keymap.set("n", "<leader>lwl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, { buffer = ev.buf, desc = "LSP: List workspace folders" })

		vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { buffer = ev.buf, desc = "LSP: Rename" })
		vim.keymap.set(
			{ "n", "v" },
			"<leader>lca",
			vim.lsp.buf.code_action,
			{ buffer = ev.buf, desc = "LSP: Code action" }
		)

		-- Replaced by conform, see ./conform.lua
		--vim.keymap.set('n', '<leader>lf', function()
		--require('')
		--end, { buffer = ev.buf, desc = "LSP: Format" })
	end,
})

-- Enable inlays
vim.lsp.inlay_hint.enable(true)

-- From https://github.com/zbirenbaum/copilot-cmp#tab-completion-configuration-highly-recommended
-- Used bellow to fix tab completion
local has_words_before = function()
	if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
		return false
	end
	local line, col = unpack(vim.api.nvim_win_get_cursor(0))
	return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
end

-- nvim-cmp (https://github.com/hrsh7th/nvim-cmp)
-- luasnip (https://github.com/L3MON4D3/LuaSnip)
local luasnip = require("luasnip")
local cmp = require("cmp")
cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},

	mapping = cmp.mapping.preset.insert({
		["<C-u>"] = cmp.mapping.scroll_docs(-4), -- Up
		["<C-d>"] = cmp.mapping.scroll_docs(4), -- Down

		-- C-b (back) C-f (forward) for snippet placeholder navigation.
		["<C-Space>"] = cmp.mapping.complete(),

		["<CR>"] = cmp.mapping.confirm({
			behavior = cmp.ConfirmBehavior.Replace,
			select = true,
		}),

		["<Tab>"] = vim.schedule_wrap(function(fallback)
			if cmp.visible() and has_words_before() then
				cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
			elseif luasnip.expand_or_jumpable() then
				luasnip.expand_or_jump()
			else
				fallback()
			end
		end, { "i", "s" }),

		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end, { "i", "s" }),
	}),

	sources = {
		{ name = "copilot" }, -- see ai.lua
		{ name = "nvim_lsp" },
		{ name = "luasnip" },
		{ name = "nvim_lsp_signature_help" },
		{ name = "buffer" },
	},
})

-------------
-- Golang
-- https://github.com/ray-x/go.nvim
if vim.fn.executable("go") == 1 then -- Only load the plugin if `go` is available since it fails otherwise
	-- Format & cleanup imports on save
	local format_sync_grp = vim.api.nvim_create_augroup("goimports", {})
	vim.api.nvim_create_autocmd("BufWritePre", {
		pattern = "*.go",
		callback = function()
			require("go.format").goimports()
		end,
		group = format_sync_grp,
	})

	require("go").setup({
		lsp_keymaps = false, -- conflicts with our remaps
		lsp_cfg = {
			settings = {
				gopls = {
					staticcheck = true,
				},
			},
		},
	})
end

------------
-- Rust
-- https://github.com/mrcjkb/rustaceanvim#gear-advanced-configuration
-- https://github.com/mrcjkb/rustaceanvim/blob/master/lua/rustaceanvim/config/internal.lua
-- See :h rustaceanvim
vim.g.rustaceanvim = {
	tools = {},
	server = {
		on_attach = function(client, bufnr) end,
		default_settings = {
			["rust-analyzer"] = {},
		},
	},
	dap = {},
}
