-- disable netrw file explorer (because we use nvim-tree)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- support for .nvim.lua or .nvimrc per project
vim.opt.exrc = true

-- pretty print
-- https://www.reddit.com/r/neovim/comments/xrovld/display_lua_tables_eg_vimkeymap/
pprint = function(v)
	print(vim.inspect(v))
	return v
end

---@param description string
---@param fn function
local try = function(description, fn)
	local success, result = pcall(fn)
	if not success then
		vim.notify("Failed to execute " .. description .. ": " .. result, vim.log.levels.ERROR)
	end
end
