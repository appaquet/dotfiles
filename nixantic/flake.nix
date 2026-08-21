{
  description = "Nixantic: a consumer-supplied instruction rendering framework";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      home-manager,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      checksFor =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        import ./checks {
          inherit
            pkgs
            home-manager
            flake-parts
            nixpkgs
            ;
          lib = nixpkgs.lib;
          coreModule = self.nixanticModules.core;
          homeManagerModule = self.homeManagerModules.default;
          flakePartsModule = self.flakeModules.default;
        };
    in
    {
      nixanticModules = {
        default = ./modules/core.nix;
        core = ./modules/core.nix;
      };
      homeManagerModules = {
        default = ./modules/home-manager.nix;
        nixantic = ./modules/home-manager.nix;
      };
      homeModules = self.homeManagerModules;
      flakeModules = {
        default = ./modules/flake-parts.nix;
        nixantic = ./modules/flake-parts.nix;
      };
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.just
              pkgs.nixfmt
            ];
          };
        }
      );
      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.nixfmt
      );
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          agentic-proj-docs = import ./tools/agentic-proj-docs.nix { inherit pkgs; };
          agentic-proj-create-adhoc = import ./tools/agentic-proj-create-adhoc.nix { inherit pkgs; };
        }
      );
      checks = forAllSystems checksFor;
    };
}
