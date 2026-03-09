# Terminal Stack: Ghostty + tmux + Neovim

Brain dump of terminal capability chain and lessons learned.

## The Stack

```
Ghostty (outer terminal) → tmux (multiplexer) → Neovim / shell (inner app)
```

Each layer has its own TERM and terminfo, creating a capability negotiation chain.

## Current Config

### Ghostty (`ghostty.nix`)
- `term = xterm-256color` — overrides Ghostty's native `xterm-ghostty` for SSH compatibility
  (remote hosts often lack `xterm-ghostty` terminfo, causing errors)
- Ghostty actually supports: true color, undercurl, colored underlines, etc.
- But because TERM is `xterm-256color`, apps don't know about advanced features

### tmux (`tmux/default.nix`)
- `default-terminal = xterm-256color` — what apps inside tmux see as `$TERM`
  - Previously was `tmux-256color`, which has `Smulx` (undercurl) in its terminfo
  - Changed to `xterm-256color` to match native Ghostty rendering (no `Smulx`, no `Setulc`)
- `terminal-overrides ',*:RGB'` — tells tmux the outer terminal supports 24-bit true color

### Neovim (`base.lua`, `theme.lua`)
- `termguicolors = true` — uses 24-bit RGB colors (bypasses 256-color palette)
- `spell = true` with `spelloptions = { "camel", "noplainbuffer" }`
  - `noplainbuffer` = only spell-check regions tagged `@spell` by treesitter
- Colorscheme: Catppuccin (mocha dark / latte light)

### Fish (`fish/default.nix`)
- `COLORTERM=truecolor` — hints to apps that true color is available
- k9s and process-compose aliased with `TERM=xterm-256color` (Go TUI tcell compatibility)

## Key Terminfo Capabilities

| Capability | What it does | `xterm-256color` | `tmux-256color` | `xterm-ghostty` |
|---|---|---|---|---|
| `RGB` / `Tc` | 24-bit true color | no (added via override) | no (added via override) | yes |
| `Smulx` | Underline styles (undercurl, dotted, dashed) | no | **yes** | **yes** |
| `Setulc` | Colored underlines (custom underline color via `sp`) | no | no | **yes** |
| `smul` / `rmul` | Basic underline on/off | yes | yes | yes |

## How Underlines Work

### The rendering chain
1. App (Neovim) checks `$TERM` terminfo for capabilities
2. If `Smulx` exists → app emits undercurl escape (`\E[4:3m`)
3. If only `smul` exists → app falls back to plain underline (`\E[4m`)
4. In tmux: tmux receives the escape, checks outer terminal's capabilities (via `terminal-overrides`),
   re-emits to outer terminal
5. Outer terminal (Ghostty) renders it

### The asymmetry problem (what we hit)
- **Native Ghostty**: `TERM=xterm-256color` → no `Smulx` → Neovim uses plain underline → clean look
- **tmux with `tmux-256color`**: has `Smulx` → Neovim uses undercurl → tmux needs outer terminal to
  also support `Smulx` (via `terminal-overrides`) to pass it through
  - Without `Smulx` override: tmux can't render undercurl → **nothing shows** (original bug)
  - With `Smulx` override: undercurl renders → red curly lines (catppuccin `SpellBad` default)

### Solution: match inner terminal to native
Using `xterm-256color` as tmux's `default-terminal` makes apps inside tmux see the same capabilities
as native Ghostty. No `Smulx` → plain underline fallback → consistent rendering.

## tmux terminal-overrides vs terminal-features

- `terminal-overrides` — modify capabilities of the **outer** terminal (what tmux connects to)
  - Example: `',*:RGB'` tells tmux "outer terminal supports true color"
  - Does NOT affect what apps inside tmux see via `$TERM`
- `terminal-features` — higher-level feature flags for the **outer** terminal (tmux 3.2+)
  - Example: `',*:usstyle'` enables underline styles AND colored underlines
  - Also does NOT affect inner `$TERM`
- `default-terminal` — sets the **inner** `$TERM` that apps see
  - This is what controls app behavior (what terminfo they read)
- `infocmp -x $TERM` inside tmux shows the **static** terminfo, not runtime overrides

## Gotchas and Lessons

1. **`term = xterm-256color` in Ghostty**: needed for SSH compatibility, but hides Ghostty's
   actual capabilities from the local stack

2. **`tmux-256color` vs `xterm-256color` as default-terminal**: `tmux-256color` has more
   capabilities (`Smulx`) which can cause rendering differences vs native terminal

3. **Catppuccin SpellBad**: sets `undercurl = true, sp = red`. When undercurl is available,
   you get red curly lines. When not, plain underline fallback (no color).

4. **`Setulc` (colored underlines)**: makes underline color follow the `sp` highlight attribute.
   Without it, underlines use foreground color. `tmux-256color` does NOT have this, but
   `xterm-ghostty` does.

5. **`noplainbuffer` spelloption**: spell only works in treesitter `@spell` regions.
   If treesitter isn't tagging comments with `@spell`, no spell checking happens there.

6. **Go TUI apps (tcell)**: older tcell versions have issues with `tmux-256color`.
   Workaround: alias with `TERM=xterm-256color` (already done for k9s, process-compose).

## If You Want Full Ghostty Features in tmux Later

To enable undercurl + colored underlines everywhere:

```
# In tmux config:
set -g default-terminal 'tmux-256color'
set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'   # undercurl passthrough
set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'  # colored underlines

# Then override Neovim highlights if you don't want red curly SpellBad:
vim.api.nvim_set_hl(0, "SpellBad", { underline = true })
```

Or use `terminal-features` (tmux 3.2+):
```
set -as terminal-features ',*:usstyle'  # enables both Smulx and Setulc
```
