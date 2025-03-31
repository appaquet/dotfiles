-- LSP
-- https://github.com/neovim/nvim-lspconfig
local lspconfig = require("lspconfig")
--lspconfig.gopls.setup {} -- Loaded by go.nvim (see bellow)
--lspconfig.rust_analyzer.setup {} -- Loaded by rustaceanvim (see bellow)
lspconfig.ts_ls.setup({})
lspconfig.marksman.setup({})
lspconfig.nixd.setup({})
lspconfig.buf_ls.setup({})
lspconfig.bashls.setup({})
lspconfig.jsonnet_ls.setup({})
lspconfig.pyright.setup({
	python = {
		analysis = {
			autoSearchPaths = true,
			diagnosticMode = "openFilesOnly",
			useLibraryCodeForTypes = true,
		},
	},
})
lspconfig.lua_ls.setup({
	-- See https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#lua_ls
	on_init = function(client)
		if client.workspace_folders then
			local path = client.workspace_folders[1].name
			if path ~= vim.fn.stdpath("config") and (vim.loop.fs_stat(path .. "/.luarc.json") or vim.loop.fs_stat(path .. "/.luarc.jsonc")) then
				return
			end
		end

		client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
			runtime = {
				-- Tell the language server which version of Lua you're using
				-- (most likely LuaJIT in the case of Neovim)
				version = "LuaJIT",
			},
			-- Make the server aware of Neovim runtime files
			workspace = {
				checkThirdParty = false,
				library = {
					vim.env.VIMRUNTIME,
					-- Depending on the usage, you might want to add additional paths here.
					-- "${3rd}/luv/library"
					-- "${3rd}/busted/library",
				},
				-- or pull in all of 'runtimepath'.
				-- NOTE: this is a lot slower and will cause issues when working on your own configuration (see https://github.com/neovim/nvim-lspconfig/issues/3189 )
				--library = vim.api.nvim_get_runtime_file("", true),
			},
		})
	end,
	settings = {
		Lua = {},
	},
})

-- Bind keymaps on lsp attach to buffer
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		-- Go to
		local opts = { buffer = ev.buf }
		vim.keymap.set("n", "<leader>lgd", vim.lsp.buf.definition, { buffer = ev.buf, desc = "LSP: Go to definition" })
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf, desc = "LSP: Go to definition" })
		vim.keymap.set("n", "<leader>lgD", vim.lsp.buf.declaration, { buffer = ev.buf, desc = "LSP: Go to declaration" })
		vim.keymap.set("n", "<leader>lgt", vim.lsp.buf.type_definition, { buffer = ev.buf, desc = "LSP: Go to type definition" })
		vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, { buffer = ev.buf, desc = "LSP: Go to type definition" })

		-- Info (more in treesietter.lua)
		vim.keymap.set("n", "<leader>lis", vim.lsp.buf.hover, { buffer = ev.buf, desc = "LSP: Displays hover information about a symbol" })

		-- List
		vim.keymap.set("n", "<leader>lli", vim.lsp.buf.implementation, { buffer = ev.buf, desc = "LSP: List all implementations" })
		vim.keymap.set("n", "<leader>llr", vim.lsp.buf.references, { buffer = ev.buf, desc = "LSP: List references" })
		vim.keymap.set("n", "<leader>ls", vim.lsp.buf.signature_help, { buffer = ev.buf, desc = "LSP: Show signature help" })

		-- Workspace
		vim.keymap.set("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, { buffer = ev.buf, desc = "LSP: Add workspace folder" })
		vim.keymap.set("n", "<leader>lwr", vim.lsp.buf.remove_workspace_folder, { buffer = ev.buf, desc = "LSP: Remove workspace folder" })
		vim.keymap.set("n", "<leader>lwl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, { buffer = ev.buf, desc = "LSP: List workspace folders" })

		-- Actions
		vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { buffer = ev.buf, desc = "LSP: Rename" })
		vim.keymap.set({ "n", "v" }, "<leader>lca", vim.lsp.buf.code_action, { buffer = ev.buf, desc = "LSP: Code action" })

		-- Formatting
		-- Replaced by conform, see ./conform.lua
		--vim.keymap.set('n', '<leader>lf', function()
		--require('')
		--end, { buffer = ev.buf, desc = "LSP: Format" })
	end,
})

-- Enable inlays
vim.lsp.inlay_hint.enable(true)
vim.keymap.set("n", "<Leader>Ti", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "LSP: Toggle inlay hints" })

-- Autocomplete
-- nvim-cmp
-- https://github.com/hrsh7th/nvim-cmp
local cmp = require("cmp")
local luasnip = require("luasnip")
cmp.setup({
	-- luasnip
	-- https://github.com/L3MON4D3/LuaSnip
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},

	preselect = cmp.PreselectMode.None, -- Don't preselect items

	mapping = cmp.mapping.preset.insert({
		["<C-u>"] = cmp.mapping.scroll_docs(-4), -- Up
		["<C-d>"] = cmp.mapping.scroll_docs(4), -- Down

		-- C-b (back) C-f (forward) for snippet placeholder navigation.
		["<C-Space>"] = cmp.mapping.complete(),

		-- Accept selected
		["<CR>"] = cmp.mapping.confirm({
			behavior = cmp.ConfirmBehavior.Replace,
			select = false, -- don't select unless selected
		}),
	}),

	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},

	sources = {
		{ name = "nvim_lsp" },
		{ name = "nvim_lsp_signature_help" },
		{ name = "luasnip" },
		{ name = "buffer" },
	},
})

-- Load default snippets
-- Can be called again to load more from specific paths (see doc or HF backend repo)
require("luasnip.loaders.from_vscode").lazy_load({})

-- Golang
-- https://github.com/ray-x/go.nvim
if vim.fn.executable("go") == 1 then -- Only load the plugin if `go` is available since it fails otherwise
	-- Format & cleanup imports on save (replaced by conform)
	--
	--local format_sync_grp = vim.api.nvim_create_augroup("goimports", {})
	--vim.api.nvim_create_autocmd("BufWritePre", {
	--pattern = "*.go",
	--callback = function()
	--require("go.format").goimports()
	--end,
	--group = format_sync_grp,
	--})

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

-- Rust
-- https://github.com/mrcjkb/rustaceanvim#gear-advanced-configuration
-- https://github.com/mrcjkb/rustaceanvim/blob/master/lua/rustaceanvim/config/internal.lua
-- See :h rustaceanvim
vim.g.rustaceanvim = {
	tools = {},
	server = {
		on_attach = function(client, bufnr)
			--
		end,
		default_settings = {
			["rust-analyzer"] = {},
		},
	},
	dap = {},
}

-- highlight todo, fixme, etc
require("todo-comments").setup({})
