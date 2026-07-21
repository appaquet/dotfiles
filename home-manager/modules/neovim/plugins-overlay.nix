final: prev: {
  vimPlugins = prev.vimPlugins // {
    # https://github.com/zbirenbaum/copilot.lua
    copilot-lua = prev.vimUtils.buildVimPlugin {
      pname = "copilot.lua";
      version = "2026-07-21";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "2a849bc7bec4d175524c332c20d48ca9ece735df";
        sha256 = "sha256-1tyiXW2O7tOr9jMDRUL2aSqQGMiSFstu6M4J/LeSQaA=";
      };
      meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
      meta.hydraPlatforms = [ ];
    };

    # https://github.com/dlyongemallo/diffview-plus.nvim
    diffview-nvim = prev.vimUtils.buildVimPlugin {
      pname = "diffview-nvim";
      version = "v0.36";
      src = prev.fetchFromGitHub {
        owner = "dlyongemallo";
        repo = "diffview-plus.nvim";
        rev = "62dc5adf4e77489a2a6d3bf36ef6e4ac5738b634";
        sha256 = "sha256-yqFT+Iastcr3YxlqjKtlDzuEvcw7oSLDGAdcEiodvs0=";
      };
      doCheck = false;
      meta.homepage = "https://github.com/dlyongemallo/diffview-plus.nvim/";
      meta.hydraPlatforms = [ ];
    };
  };
}
