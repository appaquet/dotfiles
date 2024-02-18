{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    nix-alien.url = "github:thiagokokada/nix-alien";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs"; # makes home-manager's nixpkgs input follow our nixpkgs version
    };

    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    humanfirst-dots = {
      url = "git+ssh://git@github.com/zia-ai/shared-dotfiles";
      # url = "path:/home/appaquet/dotfiles/shared-dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server.url = "github:msteen/nixos-vscode-server";
  };

  outputs = inputs @ { self, nixpkgs, nixpkgs-unstable, home-manager, humanfirst-dots, flake-utils, darwin, nix-alien, ... }:
    let
      config = {
        permittedInsecurePackages = [ ];
        allowUnfree = true;
      };

      # Add custom packages to nixpkgs
      packageOverlay = final: prev: {
      };

      overlays = [
        packageOverlay

        nix-alien.overlays.default
      ];

      commonHomeModules = [
        humanfirst-dots.homeManagerModule
      ];
    in

    flake-utils.lib.eachDefaultSystem # prevent having to hard-code system by iterating on available systems
      (system: (
        let
          pkgs = import nixpkgs {
            inherit system config overlays;
          };

          unstablePkgs = import nixpkgs-unstable {
            inherit system config overlays;
          };
        in
        {
          homes = {
            "appaquet@deskapp" = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [ ./home-manager/deskapp.nix ] ++ commonHomeModules;
              extraSpecialArgs = { inherit inputs unstablePkgs; };
            };

            "appaquet@servapp" = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [ ./home-manager/servapp.nix ] ++ commonHomeModules;
              extraSpecialArgs = { inherit inputs unstablePkgs; };
            };

            "appaquet@mbpapp" = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [ ./home-manager/mbpapp.nix ] ++ commonHomeModules;
              extraSpecialArgs = { inherit inputs unstablePkgs; };
            };
          };
        }

      )) // {

      # properly expose home configurations with appropriate expected system
      homeConfigurations = {
        "appaquet@deskapp" = self.homes.x86_64-linux."appaquet@deskapp";
        "appaquet@servapp" = self.homes.x86_64-linux."appaquet@servapp";
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
        deskapp = inputs.nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit (self) common;
            inherit inputs;
          };
          modules = [
            ./nixos/deskapp/configuration.nix
          ];
        };
      };
    };
}
