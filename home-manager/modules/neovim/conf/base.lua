
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
