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
      specialArgs = { inherit inputs; };

      modules = [
        nixosOverlaysModule
        inputs.secrets.nixos.common
        ./deskapp/configuration.nix
      ];
    };

    servapp = inputs.nixos.lib.nixosSystem {
      specialArgs = { inherit inputs; };

      modules = [
        nixosOverlaysModule
        inputs.secrets.nixos.common
        inputs.secrets.nixos.servapp
        ./servapp/configuration.nix
      ];
    };

    utm = inputs.nixos.lib.nixosSystem {
      specialArgs = { inherit inputs; };

      modules = [
        nixosOverlaysModule
        inputs.secrets.nixos.common
        ./utm/configuration.nix
      ];
    };

    piapp = inputs.nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";

      specialArgs = {
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
      };

      modules = [
        {
          imports = with inputs.nixos-raspberrypi.nixosModules; [
            raspberry-pi-5.base
            sd-image
          ];
        }
        inputs.secrets.nixos.common
        ./piapp/configuration.nix
      ];
    };

    piprint = inputs.nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";

      specialArgs = {
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
      };

      modules = [
        {
          imports = with inputs.nixos-raspberrypi.nixosModules; [
            raspberry-pi-3.base
            sd-image
          ];
        }
        inputs.secrets.nixos.common
        inputs.secrets.nixos.wifi
        ./piprint/configuration.nix
      ];
    };

    piups = inputs.nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";

      specialArgs = {
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
      };

      modules = [
        {
          imports = with inputs.nixos-raspberrypi.nixosModules; [
            raspberry-pi-3.base
            sd-image
          ];
        }
        inputs.secrets.nixos.common
        ./piups/configuration.nix
      ];
    };

    vps = inputs.nixos.lib.nixosSystem {
      specialArgs = { inherit inputs; };

      modules = [
        nixosOverlaysModule
        inputs.secrets.nixos.common
        inputs.secrets.nixos.vps
        inputs.disko.nixosModules.disko
        ./vps/configuration.nix
      ];
    };
  };
}
