{
  pkgs,
  config,
  lib,
  cfg,
  ...
}:

let
  pkgsChannel = pkgs;
  confDir = "${config.home.homeDirectory}/dotfiles/home-manager/modules/neovim/conf";

  includeLuaFile =
    path:
    if cfg.nvimDevMode then
      ''
        lua dofile("${confDir}/${path}")
      ''
    else
      ''
        lua << END
        ${builtins.readFile ./conf/${path}}
        END
      '';

  nvimEnv = ''
    let g:minimal_nvim = ${if cfg.nvimMinimal then "v:true" else "v:false"}

    if filereadable("${config.sops.secrets.nvim_secrets.path}")
      lua dofile("${config.sops.secrets.nvim_secrets.path}")
    else
      lua print("nvim secrets not found!!")
    endif
  '';
in
{
  sops.secrets.nvim_secrets.sopsFile = config.sops.secretsFiles.common;

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;

    # We only have lua and vimscript configs
    withRuby = false;
    withNodeJs = false;

    plugins =
      # Base plugins
      (with pkgsChannel.vimPlugins; [
        # Theme
        catppuccin-nvim
        nvim-web-devicons
        nvim-colorizer-lua # colorize hex codes, etc.

        # Layout
        nvim-tree-lua
        zen-mode-nvim
        mini-nvim # tabline, bufremove, etc.
        lualine-nvim # https://github.com/nvim-lualine/lualine.nvim
        nvim-navic # symbol breadcrumbs in statusline

        # Tools
        fzf-lua
        delimitMate # auto close quotes, parens, etc
        which-key-nvim # show keymap hints
        todo-comments-nvim # highlight TODO, FIXME, etc
        multicursors-nvim
        auto-session # automatically restore last session

        # Notifications
        (nvim-notify.overrideAttrs (_: {
          doCheck = false; # flaky on ci
        }))

        # Diagnostics
        trouble-nvim

        # Git
        vim-fugitive # Git (diff|log|...) commands
        gitsigns-nvim # Show git signs in gutter
        diffview-nvim # :DiffviewOpen, :DiffviewClose
        octo-nvim
        gitlinker-nvim

        # Treesitter
        (nvim-treesitter.withPlugins (p: [
          # see https://github.com/nvim-treesitter/nvim-treesitter for available languages
          p.bash
          p.c
          p.comment
          p.css
          p.dockerfile
          p.dot
          p.fish
          p.go
          p.gomod
          p.gosum
          p.gotmpl
          p.gowork
          p.html
          p.javascript
          p.json
          p.jsonnet
          p.lua
          p.markdown
          p.markdown_inline
          p.nix
          p.proto
          p.python
          p.rust
          p.sql
          p.toml
          p.typescript
          p.vim
          p.vimdoc
          p.yaml
        ]))
        nvim-treesitter-textobjects # provides object manipulation
      ])
      # Full plugins
      ++ (lib.optionals (!cfg.nvimMinimal) (
        with pkgsChannel.vimPlugins;
        [
          # LSP / Languages
          go-nvim
          neotest
          neotest-golang
          neotest-python
          rustaceanvim
          conform-nvim # formatting
          render-markdown-nvim
          nvim-lint # linting
          nvim-lsp-notify # lsp notifications

          # Autocomplete
          nvim-cmp # https://github.com/hrsh7th/nvim-cmp
          cmp-cmdline
          cmp-nvim-lsp
          cmp-nvim-lsp-signature-help
          cmp-nvim-lsp-document-symbol
          cmp-cmdline
          copilot-lua # use `Copilot auth` to login
          copilot-lsp # needed for NES on copilot-lua

          # Snippets
          luasnip
          cmp_luasnip
          friendly-snippets # easy load from vscode, languages, etc.

          # AI assistants
          codecompanion-nvim
          claudecode-nvim

          # Debugging
          nvim-dap
          nvim-dap-ui
          nvim-dap-go
          nvim-dap-python
          nvim-dap-virtual-text

          # Profiling
          snacks-nvim # nvim profiler
        ]
      ));

    extraConfig = (
      builtins.concatStringsSep "\n" (
        [
          nvimEnv
          (includeLuaFile "base.lua")

          (includeLuaFile "keymap.lua")
          (includeLuaFile "theme.lua")
          (includeLuaFile "buffers.lua")
          (includeLuaFile "windows.lua")
          (includeLuaFile "statusline.lua")
          (includeLuaFile "tree.lua")
          (includeLuaFile "sessions.lua")
          (includeLuaFile "notify.lua")
          (includeLuaFile "fzf.lua")

          (includeLuaFile "treesitter.lua")
          (includeLuaFile "git.lua")

          (includeLuaFile "quickfix.lua")
          (includeLuaFile "diag.lua")
        ]
        ++ (lib.optionals (!cfg.nvimMinimal) [
          (includeLuaFile "lang.lua")
          (includeLuaFile "formatting.lua")
          (includeLuaFile "linting.lua")

          (includeLuaFile "copilot.lua")
          (includeLuaFile "agentic.lua")

          (includeLuaFile "testing.lua")
          (includeLuaFile "debugging.lua")
          (includeLuaFile "profiling.lua")
        ])
      )
    );

    extraPackages = lib.optionals (!cfg.nvimMinimal) (
      with pkgsChannel;
      [
        nixd # nix lsp

        marksman # markdown lsp
        markdownlint-cli # via nvim-lint

        nodejs # for copilot
        typescript-language-server

        stylua # lua formatting, `npx` for some MCPs
        lua-language-server # lua lsp

        bash-language-server # bash lsp
        shfmt # shell formatting (via lsp)
        shellcheck # shell linting (via lsp)

        rust-analyzer

        pyright
        ruff
      ]
    );
  };

  # Force load after the rest
  # May have to delete session if not working, or check `:scriptnames` / `:set runtimepath?`
  xdg.configFile."nvim/after/ftplugin" = {
    recursive = true;
    source = ./ftplugin;
  };
}
