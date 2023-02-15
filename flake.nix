{
  # Created this with `nix flake init --template home-manager` then edited a few things
  description = "Home Manager configuration of Jane Doe";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11"; # <- nixos-22.11 is the release channel that includes nixos test, you can use it anywhere

    home-manager = {
      url = "github:nix-community/home-manager";

      # Makes home-manager's nixpkgs input follow our nixpkgs version
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: # destructures the input flakes
    let
      system = "aarch64-darwin";

      pkgs = import nixpkgs {
        inherit system;
        # syntax sugar for system = system;
      };
    in {
      # This is the path expected by the `home-manager` command
      # You can also do homeConfigurations."user@hostname" if you have multiple machines with the same username
      homeConfigurations.jdoe = home-manager.lib.homeManagerConfiguration {
        inherit pkgs; # same as pkgs = pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ ./home.nix ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
    };
  }
