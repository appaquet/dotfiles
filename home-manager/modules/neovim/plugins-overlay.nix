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
      version = "2025-11-04";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "389cfc58122b076e2aad1f9f34d1dfdd5a5bfd0e";
        sha256 = "sha256-1cMcUpTkFfJJ0NHklYDsMd8l1uZ94XENc46TqjhhAAw=";
      };
      meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
      meta.hydraPlatforms = [ ];
    };

    neotest = prev.vimUtils.buildVimPlugin {
      pname = "neotest";
      version = "5.13.1-patched1";
      src = prev.fetchFromGitHub {
        owner = "appaquet";
        repo = "neotest";
        rev = "fix/add-subprocess-default-init-back";
        sha256 = "sha256-NA0uBb9vu79yOjRDJdtK4S8eLqL0nRehwn8bLn7yPIs=";
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
      version = "2.5.1";
      src = prev.fetchFromGitHub {
        owner = "fredrikaverpil";
        repo = "neotest-golang";
        rev = "v2.5.1";
        sha256 = "sha256-rUuhpV/sOeIXEzuIl1nKlMQ98qrY+gE7Ng2mKu82mBA=";
      };
      propagatedBuildInputs = [
        final.vimPlugins.neotest # Use our custom neotest from this overlay
      ];
      doCheck = false;
      meta.homepage = "https://github.com/fredrikaverpil/neotest-golang/";
    };

    neotest-python = prev.vimUtils.buildVimPlugin {
      pname = "neotest-python";
      version = "2025-11-04";
      src = prev.fetchFromGitHub {
        owner = "nvim-neotest";
        repo = "neotest-python";
        rev = "b0d3a861bd85689d8ed73f0590c47963a7eb1bf9";
        sha256 = "sha256-3rK561yVzrof0WKxsKfVPeOazShllkPRVqnguNQs/x4=";
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
