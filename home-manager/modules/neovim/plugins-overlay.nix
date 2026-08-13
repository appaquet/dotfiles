final: prev: {
  vimPlugins = prev.vimPlugins // {
    # https://github.com/zbirenbaum/copilot.lua
    copilot-lua = prev.vimUtils.buildVimPlugin {
      pname = "copilot.lua";
      version = "v3.0.4";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "7e6723aabea044519462958ffcea68d7985c5ed0";
        sha256 = "sha256-nrKBq1K43l34S812udQHKIPWoSamCgQLtfYq/AjBu5I=";
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
