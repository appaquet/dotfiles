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
      version = "2025-10-10";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "92e08cd472653beaece28ad9c8508a851a613358";
        sha256 = "sha256-Jw4Q76FolG3F/AN7WZn/mNNde/21uAJ+yqESmOlyNww=";
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
      version = "2.2.0";
      src = prev.fetchFromGitHub {
        owner = "fredrikaverpil";
        repo = "neotest-golang";
        rev = "v2.2.0";
        sha256 = "sha256-dWIkH/miHixN3BTGg0MR51gvD8NFrxjUoB4vD34MJow=";
      };
      propagatedBuildInputs = [
        final.vimPlugins.neotest # Use our custom neotest from this overlay
      ];
      doCheck = false;
      meta.homepage = "https://github.com/fredrikaverpil/neotest-golang/";
    };
  };
}
