{ inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    # We use unstable nixpkgs for homes, but stable for NixOS system
    useGlobalPkgs = false;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    # Apply overlays to home-manager's pkgs
    # When adding new overlays in overlays/default.nix, also add them here
    sharedModules = [
      {
        nixpkgs.overlays = with inputs.self.overlays; [
          packages
          neovimPlugins
        ];
        nixpkgs.config.allowUnfree = true;

        # Disable version mismatch warning (NixOS stable, home-manager unstable)
        home.enableNixpkgsReleaseCheck = false;
      }
    ];
  };
}
