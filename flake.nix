{
  inputs = {
    # nixpkgs-unstable is used instead of nixos-unstable since it has no guarantee of being cached
    # use nixos-25.05 for nixos systems to have a stable system
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos.url = "github:nixos/nixpkgs/nixos-25.05";

    # pinned, issue with neotest
    nixpkgs-nvim.url = "github:NixOS/nixpkgs/e11bf63f3dc6c4c218ae32332496871f07c20329";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    humanfirst-dots = {
      url = "github:zia-ai/shared-dotfiles";
      #url = "path:/home/appaquet/dotfiles/humanfirst-dots";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    secrets = {
      url = "github:appaquet/dotfiles-secrets";
      #url = "path:/home/appaquet/dotfiles/secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fzf-nix = {
      url = "github:mrene/fzf-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixd = {
      url = "github:nix-community/nixd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server = {
      url = "github:msteen/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcphub-nvim = {
      url = "github:ravitemer/mcphub.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-hub = {
      url = "github:ravitemer/mcp-hub";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixos";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.05";
    };

    raspberry-pi-nix = {
      url = "github:nix-community/raspberry-pi-nix";
      inputs.nixpkgs.follows = "nixos";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-nvim,
      nixos,
      home-manager,
      humanfirst-dots,
      raspberry-pi-nix,
      secrets,
      flake-utils,
      darwin,
      mcp-hub,
      mcphub-nvim,
      ...
    }:
    let
      config = {
        permittedInsecurePackages = [ ];
        allowUnfree = true;
      };

      homePackageOverlays = final: prev: {
        exo = prev.callPackage ./overlays/exo { };
        claude-code = prev.callPackage ./overlays/claude-code { };
        codex = prev.callPackage ./overlays/codex { };
        mcphub-nvim = mcphub-nvim.packages."${prev.system}".default;
        mcp-hub = mcp-hub.packages."${prev.system}".default;
      };

      vimPluginsOverlay = final: prev: {
        vimPlugins = prev.vimPlugins // {
          neotest = prev.vimUtils.buildVimPlugin {
            pname = "neotest";
            version = "5.13.0";
            src = prev.fetchFromGitHub {
              owner = "nvim-neotest";
              repo = "neotest";
              rev = "v5.13.0";
              sha256 = "sha256-IzR32B0B+0DYGc7SRgIalWNJjMCM51NjcL0RT7SlzdU=";
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
              final.vimPlugins.neotest  # Use our custom neotest from this overlay
            ];
            doCheck = false;
            meta.homepage = "https://github.com/fredrikaverpil/neotest-golang/";
          };
        };
      };

      homeOverlays = [
        homePackageOverlays
        vimPluginsOverlay
      ];

      commonHomeModules = [
        humanfirst-dots.homeManagerModule
      ];

      nixosOverlays = [
      ];
      nixosOverlaysModule = (
        _: {
          nixpkgs.overlays = nixosOverlays;
        }
      );
    in

    flake-utils.lib.eachDefaultSystem # prevent having to hard-code system by iterating on available systems
      (
        system:
        (
          let
            pkgs = import nixpkgs {
              inherit system config;
              overlays = homeOverlays;
            };
            pkgs-nvim = import nixpkgs-nvim {
              inherit system config;
              overlays = homeOverlays;
            };

            cfg = {
              isNixos = false;
              minimalNvim = false;
            };
          in
          {
            homes = {
              "appaquet@deskapp" = home-manager.lib.homeManagerConfiguration rec {
                inherit pkgs;
                modules = [
                  ./home-manager/deskapp.nix
                  extraSpecialArgs.secrets.commonHome
                ]
                ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs;
                  pkgs-nvim = pkgs-nvim;
                  secrets = secrets.init "linux";
                  cfg = cfg // {
                    isNixos = true;
                  };
                };
              };

              "appaquet@servapp" = home-manager.lib.homeManagerConfiguration rec {
                inherit pkgs;
                modules = [
                  ./home-manager/servapp.nix
                  extraSpecialArgs.secrets.commonHome
                ]
                ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs;
                  secrets = secrets.init "linux";
                  pkgs-nvim = pkgs-nvim;
                  cfg = cfg // {
                    isNixos = true;
                  };
                };
              };

              "appaquet@mbpapp" = home-manager.lib.homeManagerConfiguration rec {
                inherit pkgs;
                modules = [
                  ./home-manager/mbpapp.nix
                  extraSpecialArgs.secrets.commonHome
                ]
                ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs cfg;
                  pkgs-nvim = pkgs-nvim;
                  secrets = secrets.init "darwin";
                };
              };

              "appaquet@piapp" = home-manager.lib.homeManagerConfiguration rec {
                inherit pkgs;
                modules = [
                  ./home-manager/piapp.nix
                  extraSpecialArgs.secrets.commonHome
                ]
                ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs;
                  secrets = secrets.init "linux";
                  pkgs-nvim = pkgs-nvim;
                  cfg = cfg // {
                    isNixos = true;
                    minimalNvim = true;
                  };
                };
              };

              "appaquet@utm" = home-manager.lib.homeManagerConfiguration rec {
                inherit pkgs;
                modules = [
                  ./home-manager/utm.nix
                  extraSpecialArgs.secrets.commonHome
                ]
                ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs;
                  secrets = secrets.init "linux";
                  pkgs-nvim = pkgs-nvim;
                  cfg = cfg // {
                    isNixos = true;
                    minimalNvim = true;
                  };
                };
              };
            };
          }
        )
      )
    // {

      # properly expose home configurations with appropriate expected system
      homeConfigurations = {
        "appaquet@deskapp" = self.homes.x86_64-linux."appaquet@deskapp";
        "appaquet@servapp" = self.homes.x86_64-linux."appaquet@servapp";
        "appaquet@utm" = self.homes.aarch64-linux."appaquet@utm";
        "appaquet@piapp" = self.homes.aarch64-linux."appaquet@piapp";
        "appaquet@mbpapp" = self.homes.aarch64-darwin."appaquet@mbpapp";
      };

      darwinConfigurations = {
        mbpapp = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          # pkgs = import nixpkgs-darwin {
          #   inherit config;
          #   system = "aarch64-darwin";
          # };
          modules = [
            ./darwin/mbpapp/configuration.nix
          ];
          # inputs = { inherit inputs darwin; };
          specialArgs = { inherit inputs; };
        };
      };

      nixosConfigurations = {
        deskapp = nixos.lib.nixosSystem {
          specialArgs = {
            inherit (self) common;
            inherit inputs;
            secrets = secrets.init "linux";
          };
          modules = [
            nixosOverlaysModule
            ./nixos/deskapp/configuration.nix
          ];
        };

        servapp = nixos.lib.nixosSystem {
          specialArgs = {
            inherit (self) common;
            inherit inputs;
            secrets = secrets.init "linux";
          };
          modules = [
            nixosOverlaysModule
            ./nixos/servapp/configuration.nix
          ];
        };

        utm = nixos.lib.nixosSystem {
          specialArgs = {
            inherit (self) common;
            inherit inputs;
            secrets = secrets.init "linux";
          };
          modules = [
            nixosOverlaysModule
            ./nixos/utm/configuration.nix
          ];
        };

        piapp = nixos.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {
            inherit (self) common;
            inherit inputs;
            secrets = secrets.init "linux";
          };
          modules = [
            nixosOverlaysModule
            raspberry-pi-nix.nixosModules.raspberry-pi
            raspberry-pi-nix.nixosModules.sd-image
            ./nixos/piapp/configuration.nix
          ];
        };
      };
    };
}
