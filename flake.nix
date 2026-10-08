{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos.url = "github:nixos/nixpkgs/nixos-26.05";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixantic = {
      #url = "path:/home/appaquet/dotfiles/nixantic";
      url = "github:appaquet/nixantic";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.home-manager.follows = "home-manager";
    };

    secrets = {
      url = "github:appaquet/dotfiles-secrets";
      #url = "path:/home/appaquet/dotfiles/secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotblip = {
      url = "github:appaquet/dotblip";
      # url = "path:/home/appaquet/dotfiles/dotblip";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixos";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixos";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixos"; # need to be on same channel
    };

    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { inputs, ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        imports = [
          inputs.nixantic.flakeModules.default
          ./overlays
          ./home-manager/modules/agentic/flake-module.nix
          ./home-manager/modules/git/flake-module.nix
          ./home-manager/modules/ssh/flake-module.nix
          ./home-manager
          ./nixos
          ./darwin
        ];

        perSystem =
          { pkgs, ... }:
          {
            devShells.default = pkgs.mkShell {
              packages = [
                pkgs.bun
                pkgs.just
                pkgs.nixfmt
              ];
            };
          };
      }
    );
}
