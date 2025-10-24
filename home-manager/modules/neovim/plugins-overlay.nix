final: prev: {
  vimPlugins = prev.vimPlugins // {
    # Forked from https://github.com/mrded/nvim-lsp-notify
    nvim-lsp-notify = prev.vimUtils.buildVimPlugin {
      name = "lsp-notify";
      src = ./plugins/lsp-notify;
    };

    copilot-lsp = prev.vimUtils.buildVimPlugin {
      pname = "copilot-lsp";
      version = "2025-10-01";
      src = prev.fetchFromGitHub {
        owner = "copilotlsp-nvim";
        repo = "copilot-lsp";
        rev = "a80e0c17e7366614d39506825f49a25d285fead9";
        sha256 = "sha256-Mch675Wmx+8EbvsQ/y5H/eyObsKjotlEe26JKhwBfEA=";
      };
      meta.homepage = "https://github.com/copilotlsp-nvim/copilot-lsp/";
      meta.hydraPlatforms = [ ];
    };

    copilot-lua = prev.vimUtils.buildVimPlugin {
      pname = "copilot.lua";
      version = "2025-10-24";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "7fe314ffa6c7bbf1b7d1dc6836d9603fd9623f07";
        sha256 = "sha256-MIPHNBVW84zG5xY/E0kTtvtKbr+QwH7lIGiLKKuGjHw=";
      };
      meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
      meta.hydraPlatforms = [ ];
    };

    neotest = prev.vimUtils.buildVimPlugin {
      pname = "neotest";
      version = "5.13.0-patched1";
      src = prev.fetchFromGitHub {
        owner = "appaquet";
        repo = "neotest";
        rev = "fix/add-subprocess-default-init-back";
        sha256 = "sha256-Udf0RZIrll9VGi30YXTKa9Ozj9xb5ZBDMBj6/ikfm8A=";
      };
      propagatedBuildInputs = with prev.vimPlugins; [
        nvim-nio
        plenary-nvim
      ];
      doCheck = false;
      meta.homepage = "https://github.com/nvim-neotest/neotest";
    };

    neotest-golang = prev.vimUtils.buildVimPlugin {
      pname = "neotest-golang";
      version = "2.4.0";
      src = prev.fetchFromGitHub {
        owner = "fredrikaverpil";
        repo = "neotest-golang";
        rev = "v2.4.0";
        sha256 = "sha256-zDkV0QKZN3B04owMNG8QcjK86wV7DkN/MP/y0oHs6X8=";
      };
      propagatedBuildInputs = [
        final.vimPlugins.neotest # Use our custom neotest from this overlay
      ];
      doCheck = false;
      meta.homepage = "https://github.com/fredrikaverpil/neotest-golang/";
    };

    neotest-python = prev.vimUtils.buildVimPlugin {
      pname = "neotest-python";
      version = "2024-10-02";
      src = prev.fetchFromGitHub {
        owner = "nvim-neotest";
        repo = "neotest-python";
        rev = "a2861ab3c9a0bf75a56b11835c2bfc8270f5be7e";
        sha256 = "1m78f9bxsl548f1pcrmbndmnwdplvhqynpm86pv080272ci9msgy";
      };
      propagatedBuildInputs = [
        final.vimPlugins.neotest # Use our custom neotest from this overlay
      ];
      doCheck = false;
      meta.homepage = "https://github.com/nvim-neotest/neotest-python/";
      meta.hydraPlatforms = [ ];
    };
  };
}
