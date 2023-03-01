{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";

      # Makes home-manager's nixpkgs input follow our nixpkgs version
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, home-manager, flake-utils, darwin, ... }:
    let
      config = {
        permittedInsecurePackages = [ ];
        allowUnfree = true;
      };

      # Add custom packages to nixpkgs
      packageOverlay = final: prev: {
        rtx = prev.callPackage ./packages/rtx { };
      };

      overlays = [
        packageOverlay
      ];
    in

    flake-utils.lib.eachDefaultSystem
      (system: (
        let
          pkgs = import nixpkgs {
            inherit system overlays config;
          };
        in
        {
          homes = {
            "appaquet@deskapp" = home-manager.lib.homeManagerConfiguration {
              pkgs = import nixpkgs {
                inherit system overlays config;
              };
              modules = [ ./home-manager/deskapp.nix ];
              extraSpecialArgs = { inherit inputs; };
            };

            "appaquet@mbpapp" = home-manager.lib.homeManagerConfiguration {
              pkgs = import nixpkgs {
                inherit system overlays config;
              };
              modules = [ ./home-manager/mbpapp.nix ];
              extraSpecialArgs = { inherit inputs; };
            };
          };
        }

      )) // {

      homeConfigurations = {
        "appaquet@deskapp" = self.homes.x86_64-linux."appaquet@deskapp";
        "appaquet@mbpapp" = self.homes.aarch64-darwin."appaquet@mbpapp";
      };

      darwinConfigurations = {
        # nix build .#darwinConfigurations.mbmapp.system
        # ./result/sw/bin/darwin-rebuild switch --flake .
        mbpapp = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          pkgs = import nixpkgs {
            inherit config overlays;
            system = "aarch64-darwin";
          };
          modules = [
            ./darwin/mbpapp/configuration.nix
          ];
          inputs = { inherit inputs darwin; };
        };
      };

    };
}
