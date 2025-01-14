{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    nix-alien.url = "github:thiagokokada/nix-alien";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

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

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
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
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      humanfirst-dots,
      raspberry-pi-nix,
      secrets,
      flake-utils,
      darwin,
      ...
    }:
    let
      config = {
        permittedInsecurePackages = [ ];
        allowUnfree = true;
      };

      homePackageOverlays = final: prev: {
        exo = prev.callPackage ./overlays/exo { };
      };

      homeOverlays = [
        homePackageOverlays
        inputs.nix-alien.overlays.default
      ];

      commonHomeModules = [
        humanfirst-dots.homeManagerModule
      ];

      nixosOverlays = [
        inputs.nix-alien.overlays.default
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

            unstablePkgs = import nixpkgs-unstable {
              inherit system config;
              overlays = homeOverlays;
            };

            cfg = {
              isNixos = false;
            };
          in
          {
            homes = {
              "appaquet@deskapp" = home-manager.lib.homeManagerConfiguration rec {
                inherit pkgs;
                modules = [
                  ./home-manager/deskapp.nix
                  extraSpecialArgs.secrets.commonHome
                ] ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs unstablePkgs;
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
                ] ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs unstablePkgs;
                  secrets = secrets.init "linux";
                  cfg = cfg // {
                    isNixos = true;
                  };
                };
              };

              "appaquet@utm" = home-manager.lib.homeManagerConfiguration rec {
                inherit pkgs;
                modules = [
                  ./home-manager/utm.nix
                  extraSpecialArgs.secrets.commonHome
                ] ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs unstablePkgs;
                  secrets = secrets.init "linux";
                  cfg = cfg // {
                    isNixos = true;
                  };
                };
              };

              "appaquet@piapp" = home-manager.lib.homeManagerConfiguration rec {
                inherit pkgs;
                modules = [
                  ./home-manager/piapp.nix
                  extraSpecialArgs.secrets.commonHome
                ] ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs unstablePkgs;
                  secrets = secrets.init "linux";
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
                ] ++ commonHomeModules;
                extraSpecialArgs = {
                  inherit inputs unstablePkgs cfg;
                  secrets = secrets.init "darwin";
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
          pkgs = import nixpkgs {
            inherit config;
            system = "aarch64-darwin";
          };
          modules = [
            ./darwin/mbpapp/configuration.nix
          ];
          inputs = { inherit inputs darwin; };
        };
      };

      nixosConfigurations = {
        deskapp = nixpkgs.lib.nixosSystem {
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

        servapp = nixpkgs.lib.nixosSystem {
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

        utm = nixpkgs.lib.nixosSystem {
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

        piapp = nixpkgs.lib.nixosSystem {
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
