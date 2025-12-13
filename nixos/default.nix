{ inputs, ... }:
let
  nixosOverlays = [
    # ...
  ];

  nixosOverlaysModule = _: { nixpkgs.overlays = nixosOverlays; };
in
{
  flake.nixosConfigurations = {
    deskapp = inputs.nixos.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        secrets = inputs.secrets.linux;
      };

      modules = [
        nixosOverlaysModule
        ./deskapp/configuration.nix
      ];
    };

    servapp = inputs.nixos.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        secrets = inputs.secrets.linux;
      };

      modules = [
        nixosOverlaysModule
        ./servapp/configuration.nix
      ];
    };

    utm = inputs.nixos.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        secrets = inputs.secrets.linux;
      };

      modules = [
        nixosOverlaysModule
        ./utm/configuration.nix
      ];
    };

    piapp = inputs.nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";

      specialArgs = {
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
        secrets = inputs.secrets.linux;
      };

      modules = [
        {
          imports = with inputs.nixos-raspberrypi.nixosModules; [
            raspberry-pi-5.base
            sd-image
          ];
        }
        ./piapp/configuration.nix
      ];
    };

    piprint = inputs.nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";

      specialArgs = {
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
        secrets = inputs.secrets.linux;
      };

      modules = [
        {
          imports = with inputs.nixos-raspberrypi.nixosModules; [
            raspberry-pi-3.base
            sd-image
          ];
        }
        ./piprint/configuration.nix
      ];
    };

    piups = inputs.nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";

      specialArgs = {
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
        secrets = inputs.secrets.linux;
      };

      modules = [
        {
          imports = with inputs.nixos-raspberrypi.nixosModules; [
            raspberry-pi-3.base
            sd-image
          ];
        }
        ./piups/configuration.nix
      ];
    };
  };
}
