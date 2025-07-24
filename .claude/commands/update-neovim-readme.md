# Update Neovim README

Update the README.nvim.md file at the root of the repository to ensure all keybindings are documented and accurate.

## Instructions

1. Read the README.nvim.md file at the root of the repository.

2. For each file in home-manager/modules/neovim/conf/, extract all keybindings defined in the config files.

3. Compare keybindings in config files with those documented in README and:
   - Add missing keybindings from config files to README
   - Remove keybindings from README that are not in the config files

4. Add plugin/source indicators in parentheses after keybinding descriptions:
   - `(native)` for built-in Neovim keybindings
   - `(plugin-name)` for keybindings provided by specific plugins (e.g., `(treesitter)`, `(gitlinker)`, etc.)
   - No indicator needed for custom keybindings defined in the config files

5. Organize keybindings logically by category and maintain consistent formatting.

6. Propose removal of any keybindings that are documented but not actually available in the configuration.

## Plugin Indicators Reference

Common plugins that provide keybindings:
- `(native)` - Built-in Neovim functionality
- `(treesitter)` - nvim-treesitter plugin functions
- `(gitlinker)` - gitlinker.nvim plugin
- `(which-key)` - Enhanced with which-key display
- Add others as discovered during the update

## Notes

- Focus on keybindings that users would actually press, not internal configuration
- Maintain the existing section structure in the README
- Keep descriptions concise but informative
- Ensure all leader key mappings are correctly documented