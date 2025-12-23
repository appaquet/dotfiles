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
        secrets = inputs.secrets.linux; # LEGACY: remove after full migration
      };

      modules = [
        nixosOverlaysModule
        inputs.secrets.nixosModules.sops
        ./deskapp/configuration.nix
      ];
    };

    servapp = inputs.nixos.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        secrets = inputs.secrets.linux; # LEGACY: remove after full migration
      };

      modules = [
        nixosOverlaysModule
        inputs.secrets.nixosModules.sops
        inputs.secrets.nixos.servapp
        ./servapp/configuration.nix
      ];
    };

    utm = inputs.nixos.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        secrets = inputs.secrets.linux; # LEGACY: remove after full migration
      };

      modules = [
        nixosOverlaysModule
        inputs.secrets.nixosModules.sops
        ./utm/configuration.nix
      ];
    };

    piapp = inputs.nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";

      specialArgs = {
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
        secrets = inputs.secrets.linux; # LEGACY: remove after full migration
      };

      modules = [
        {
          imports = with inputs.nixos-raspberrypi.nixosModules; [
            raspberry-pi-5.base
            sd-image
          ];
        }
        inputs.secrets.nixosModules.sops
        ./piapp/configuration.nix
      ];
    };

    piprint = inputs.nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";

      specialArgs = {
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
        secrets = inputs.secrets.linux; # LEGACY: remove after full migration
      };

      modules = [
        {
          imports = with inputs.nixos-raspberrypi.nixosModules; [
            raspberry-pi-3.base
            sd-image
          ];
        }
        inputs.secrets.nixosModules.sops
        ./piprint/configuration.nix
      ];
    };

    piups = inputs.nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";

      specialArgs = {
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
        secrets = inputs.secrets.linux; # LEGACY: remove after full migration
      };

      modules = [
        {
          imports = with inputs.nixos-raspberrypi.nixosModules; [
            raspberry-pi-3.base
            sd-image
          ];
        }
        inputs.secrets.nixosModules.sops
        ./piups/configuration.nix
      ];
    };
  };
}
