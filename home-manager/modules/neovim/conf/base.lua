
-- Load a plugin only when opening a file pattern for the first time
function load_plugin_on_first_open(plugin_name, ft, setup_fn)
  local loaded = false
  vim.api.nvim_create_autocmd("FileType", {
    pattern = ft,
    callback = function(args)
      if not loaded and vim.bo[args.buf].filetype ~= "" then
        loaded = true
        setup_fn()
      end
    end,
    desc = "Load plugin " .. plugin_name .. " on first file type detection"
  })
end

