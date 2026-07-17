final: prev: {
  vimPlugins = prev.vimPlugins // {
    # https://github.com/zbirenbaum/copilot.lua
    copilot-lua = prev.vimUtils.buildVimPlugin {
      pname = "copilot.lua";
      version = "2026-07-04";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "d521d3959f81f4fa58870ed329754f1dd5057511";
        sha256 = "sha256-5n5wogPhLmej9ov62qHFKZMNYhKGiz+zjQwPExGaKTI=";
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
        rev = "424b724e7699730b818466532f0ca42930313273";
        sha256 = "sha256-tsL0eeTE5F81GzrvvAx0SEH461AYE5H1OWL8PdokshE=";
      };
      doCheck = false;
      meta.homepage = "https://github.com/dlyongemallo/diffview-plus.nvim/";
      meta.hydraPlatforms = [ ];
    };
  };
}
