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

    in

    flake-utils.lib.eachDefaultSystem
      (system: (
        let
          pkgs = import nixpkgs {
            inherit system config;
          };
        in
        {
          homes = {
            "appaquet@deskapp" = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [ ./packages/home-manager/deskapp.nix ];
              extraSpecialArgs = { inherit inputs; };
            };

            "appaquet@mbpapp" = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [ ./packages/home-manager/mbpapp.nix ];
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
        # nix build .#darwinConfigurations.mbp2021.system
        # ./result/sw/bin/darwin-rebuild switch --flake .
        mbpvmapp = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          pkgs = import nixpkgs {
            inherit config;
            system = "aarch64-darwin";
          };
          modules = [
            ./packages/darwin/mbp2021/configuration.nix
          ];
          inputs = { inherit inputs darwin; };
        };
      };

    };
}
