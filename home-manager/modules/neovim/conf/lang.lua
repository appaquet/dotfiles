require("which-key").add({
	{ "<leader>l", group = "LSP" },
})

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

if vim.fn.executable("ruff") == 1 then -- Only load if ruff is available
	lspconfig.ruff.setup({ -- https://docs.astral.sh/ruff/editors/setup/#neovim
		init_options = {
			settings = {
				logLevel = "debug",
			},
		},
	})
end

lspconfig.lua_ls.setup({
	-- See https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#lua_ls
	on_init = function(client)
		if client.workspace_folders then
			local path = client.workspace_folders[1].name
			if path ~= vim.fn.stdpath("config") and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.loop.fs_stat(path .. "/.luarc.jsonc")) then
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
		local fzf = require("fzf-lua")

		local function kopts(buffer, desc)
			return { buffer = buffer, desc = desc }
		end

		local function goto_definition_float()
			AwaitBufferChange(function()
				vim.lsp.buf.definition()
			end)
			PopBufferToFloat()
		end

		local function goto_type_definition_float()
			AwaitBufferChange(function()
				vim.lsp.buf.type_definition()
			end)
			PopBufferToFloat()
		end

		local function goto_definition_right()
			AwaitBufferChange(function()
				vim.lsp.buf.definition()
			end)
			PopBufferToRight()
		end

		local function goto_type_definition_right()
			AwaitBufferChange(function()
				vim.lsp.buf.type_definition()
			end)
			PopBufferToRight()
		end

		require("which-key").add({
			{ "<leader>li", group = "LSP: Info..." },
			{ "<leader>ll", group = "LSP: List..." },
			{ "<leader>lg", group = "LSP: Goto..." },
			{ "<leader>lw", group = "LSP: Workspace..." },
			{ "<leader>lc", group = "LSP: Actions..." },
		})

		-- Go to
		vim.keymap.set("n", "<leader>lgd", vim.lsp.buf.definition, kopts(ev.buf, "LSP: Go to definition"))
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, kopts(ev.buf, "LSP: Go to definition"))
		vim.keymap.set("n", "gfd", goto_definition_float, kopts(ev.buf, "LSP: Go to definition (in floating window)"))
		vim.keymap.set("n", "gld", goto_definition_right, kopts(ev.buf, "LSP: Go to definition (in right split)"))

		vim.keymap.set("n", "<leader>lgt", vim.lsp.buf.type_definition, kopts(ev.buf, "LSP: Go to type definition"))
		vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, kopts(ev.buf, "LSP: Go to type definition"))
		vim.keymap.set("n", "gft", goto_type_definition_float, kopts(ev.buf, "LSP: Go to type definition (in floating window)"))
		vim.keymap.set("n", "glt", goto_type_definition_right, kopts(ev.buf, "LSP: Go to type definition (in right split)"))

		vim.keymap.set("n", "gr", fzf.lsp_references, kopts(ev.buf, "LSP: Go to references"))

		-- Info (more in treesitter.lua)
		vim.keymap.set("n", "<leader>lii", vim.lsp.buf.hover, kopts(ev.buf, "LSP: Displays hover information about a symbol"))
		vim.keymap.set("n", "<leader>lis", vim.lsp.buf.signature_help, kopts(ev.buf, "LSP: Show signature help"))

		-- List
		vim.keymap.set("n", "<leader>lli", fzf.lsp_implementations, kopts(ev.buf, "LSP: List all implementations"))
		vim.keymap.set("n", "<leader>llr", fzf.lsp_references, kopts(ev.buf, "LSP: List references"))

		-- Workspace
		vim.keymap.set("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, kopts(ev.buf, "LSP: Add workspace folder"))
		vim.keymap.set("n", "<leader>lwr", vim.lsp.buf.remove_workspace_folder, kopts(ev.buf, "LSP: Remove workspace folder"))
		vim.keymap.set("n", "<leader>lwl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, kopts(ev.buf, "LSP: List workspace folders"))

		-- Actions
		vim.keymap.set({ "n", "v" }, "<leader>lca", vim.lsp.buf.code_action, kopts(ev.buf, "LSP: Code action"))
		vim.keymap.set({ "i", "v" }, "<C-l>ca", vim.lsp.buf.code_action, kopts(ev.buf, "LSP: Code action"))
		vim.keymap.set({ "n", "v" }, "<leader>lr", vim.lsp.buf.rename, kopts(ev.buf, "LSP: Rename"))
		vim.keymap.set({ "i", "v" }, "<C-l>r", vim.lsp.buf.rename, kopts(ev.buf, "LSP: Rename"))
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
		-- Accept selected
		["<CR>"] = cmp.mapping.confirm({
			behavior = cmp.ConfirmBehavior.Insert,
			select = false, -- don't select unless selected
		}),
		["<S-CR>"] = cmp.mapping.confirm({
			behavior = cmp.ConfirmBehavior.Replace,
			select = false, -- don't select unless selected
		}),

		-- Documentation pane navigation
		["<C-u>"] = cmp.mapping.scroll_docs(-4), -- Up
		["<C-d>"] = cmp.mapping.scroll_docs(4), -- Down
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
	vim.keymap.set({ "n", "v" }, "<leader>lci", ":GoImports<CR>", { silent = true, desc = "LSP: Fix imports" })
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
