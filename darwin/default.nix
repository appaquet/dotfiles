{ inputs, ... }:
{
  flake.darwinConfigurations = {
    mbpapp = inputs.darwin.lib.darwinSystem {
      system = "aarch64-darwin";

      modules = [
        ./mbpapp/configuration.nix
      ];

      specialArgs = {
        inherit inputs;
      };
    };
  };
}
