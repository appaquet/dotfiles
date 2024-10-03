{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    nix-alien.url = "github:thiagokokada/nix-alien";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    humanfirst-dots = {
      url = "github:zia-ai/shared-dotfiles";
      #url = "path:/home/appaquet/dotfiles/humanfirst-dots";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    secrets = {
      url = "github:appaquet/dotfiles-secrets";
      # url = "path:/home/appaquet/dotfiles/secrets";
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

  outputs = inputs @ { self, nixpkgs, nixpkgs-unstable, home-manager, humanfirst-dots, secrets, flake-utils, darwin, ... }:
    let
      config = {
        permittedInsecurePackages = [ ];
        allowUnfree = true;
      };

      packageOverlays = final: prev: {
        exo = prev.callPackage ./overlays/exo { };
        fzf-nix = inputs.fzf-nix.packages.${prev.system}.fzf-nix;
      };

      homeOverlays = [
        packageOverlays
        inputs.nix-alien.overlays.default
      ];

      commonHomeModules = [
        humanfirst-dots.homeManagerModule
      ];

      nixosOverlays = [
        inputs.nix-alien.overlays.default
      ];
      nixosOverlaysModule = (_: {
        nixpkgs.overlays = nixosOverlays;
      });
    in

    flake-utils.lib.eachDefaultSystem # prevent having to hard-code system by iterating on available systems
      (system: (
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

            "appaquet@nixapp" = home-manager.lib.homeManagerConfiguration rec {
              inherit pkgs;
              modules = [
                ./home-manager/nixapp.nix
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
                inherit inputs unstablePkgs cfg;
                secrets = secrets.init "linux";
              };
            };

            "appaquet@mbpapp" = home-manager.lib.homeManagerConfiguration rec{
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

      )) // {

      # properly expose home configurations with appropriate expected system
      homeConfigurations = {
        "appaquet@deskapp" = self.homes.x86_64-linux."appaquet@deskapp";
        "appaquet@servapp" = self.homes.x86_64-linux."appaquet@servapp";
        "appaquet@nixapp" = self.homes.x86_64-linux."appaquet@nixapp";
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
        nixapp = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit (self) common;
            inherit inputs;
            secrets = secrets.init "linux";
          };
          modules = [
            nixosOverlaysModule
            ./nixos/nixapp/configuration.nix
          ];
        };

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
      };
    };
}
