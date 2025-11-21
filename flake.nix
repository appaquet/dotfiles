{
  inputs = {
    # nixpkgs-unstable is used instead of nixos-unstable since it has no guarantee of being cached
    # use nixos-25.05 for nixos systems to have a stable system
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos.url = "github:nixos/nixpkgs/nixos-25.05";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    humanfirst-dots = {
      url = "github:zia-ai/shared-dotfiles";
      #url = "path:/home/appaquet/dotfiles/humanfirst-dots";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    secrets = {
      #url = "github:appaquet/dotfiles-secrets";
      url = "path:/Users/appaquet/dotfiles/secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fzf-nix = {
      url = "github:mrene/fzf-nix";

      # use slower channel, but more stable and prevent rebuilding often
      # since it needs to reindex nix packages on each update
      inputs.nixpkgs.follows = "nixos";
    };

    nixd = {
      url = "github:nix-community/nixd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server = {
      url = "github:msteen/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixos";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.05";
    };

    nixos-raspberrypi-nixpkgs = {
      url = "github:nvmd/nixpkgs/modules-with-keys-25.05";
    };
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs.nixpkgs.follows = "nixos-raspberrypi-nixpkgs";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        imports = [
          ./overlays
          ./home-manager
          ./nixos
          ./darwin
        ];
      }
    );
}
