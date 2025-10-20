# Update Neovim Cheat Sheet

Update my neovim cheat sheet file to ensure all keybindings are documented and accurate.

## Instructions

1. Read the ./docs/cheatsheets/nvim.md from the root of the repository.

2. For each file in home-manager/modules/neovim/conf/, extract all keybindings defined in the config files.

3. Compare keybindings in config files with those documented in my cheat sheet and:
   - Add missing keybindings from config files to the cheat sheet
   - Remove keybindings from the cheat sheet that are not in the config files

4. Organize keybindings logically by category and maintain consistent formatting.

5. Propose removal of any keybindings that are documented but not actually available in the configuration.

6. Keep descriptions clean and concise without adding plugin indicators in parentheses.

## Notes

- Focus on keybindings that users would actually press, not internal configuration
- Maintain the existing section structure in the cheat sheet
- Keep descriptions concise but informative
- Ensure all leader key mappings are correctly documented
