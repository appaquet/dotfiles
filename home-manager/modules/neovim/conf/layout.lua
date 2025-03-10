

-------------
--- nvim-tree
-- empty setup using defaults
require("nvim-tree").setup {
    update_focused_file = {
        enable = true,
    },
    diagnostics = {
      enable = true,
      show_on_dirs = true,
    },

    actions = {
      open_file = {
        resize_window = false, -- Prevent resizing tree on opening file
      },
    },
    view = {
      preserve_window_proportions = false,
    },
}
vim.keymap.set('n', '<Leader>e', ':NvimTreeToggle<CR>', { desc = "Tree: Toggle" })

---------------
--- bufferline
require("bufferline").setup {
  options = {
    show_duplicate_prefix = true,
    offsets = {
        {
            filetype = "NvimTree",
            text = "File Explorer",
            text_align = "center",
            separator = true,
        }
    },
  },
}

------------
--- lualine
--- https://github.com/nvim-lualine/lualine.nvim
require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'catppuccin',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
