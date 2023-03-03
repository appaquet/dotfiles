{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
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
  };

  outputs = inputs @ { self, nixpkgs, nixpkgs-unstable, home-manager, humanfirst-dots, flake-utils, darwin, ... }:
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

      commonHomeModules = [
        humanfirst-dots.homeManagerModule
      ];
    in

    flake-utils.lib.eachDefaultSystem # prevent having to hard-code system by iterating on available systems
      (system: (
        let
          pkgs = import nixpkgs {
            inherit system overlays config;
          };

          unstablePkgs = import nixpkgs-unstable {
            inherit system overlays config;
          };
        in
        {
          homes = {
            "appaquet@deskapp" = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [ ./home-manager/deskapp.nix ] ++ commonHomeModules;
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
        "appaquet@mbpapp" = self.homes.aarch64-darwin."appaquet@mbpapp";
      };

      darwinConfigurations = {
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
