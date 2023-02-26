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

  outputs = { nixpkgs, home-manager, flake-utils, ... }: # destructures the input flakes
    flake-utils.lib.eachDefaultSystem
      (system: (
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          homeConfigurations = {
            "appaquet@deskapp" = home-manager.lib.homeManagerConfiguration {
              inherit pkgs; # same as pkgs = pkgs;

              # Specify your home configuration modules here, for example,
              # the path to your home.nix.
              modules = [ ./home-manager/deskapp.nix ];

              # Optionally use extraSpecialArgs
              # to pass through arguments to home.nix
            };

            "appaquet@mbpapp" = home-manager.lib.homeManagerConfiguration {
              inherit pkgs; # same as pkgs = pkgs;

              # Specify your home configuration modules here, for example,
              # the path to your home.nix.
              modules = [ ./home-manager/mbpapp.nix ];

              # Optionally use extraSpecialArgs
              # to pass through arguments to home.nix
            };
          };
        }
      ));
}
