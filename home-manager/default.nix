{ inputs, withSystem, ... }:
let
  mkHomeConfig =
    system: hostModule:
    withSystem system (
      { pkgs, inputs', ... }:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ hostModule ];
        extraSpecialArgs = { inherit inputs inputs'; };
      }
    );
in
{
  flake.homeConfigurations = {
    "appaquet@deskapp" = mkHomeConfig "x86_64-linux" ./deskapp.nix;
    "appaquet@servapp" = mkHomeConfig "x86_64-linux" ./servapp.nix;
    "appaquet@mbpapp" = mkHomeConfig "aarch64-darwin" ./mbpapp.nix;
    "appaquet@utm" = mkHomeConfig "aarch64-linux" ./utm.nix;
    "appaquet@piapp" = mkHomeConfig "aarch64-linux" ./piapp.nix;
    "appaquet@piprint" = mkHomeConfig "aarch64-linux" ./piprint.nix;
    "appaquet@piups" = mkHomeConfig "aarch64-linux" ./piups.nix;
    "appaquet@vps" = mkHomeConfig "x86_64-linux" ./vps.nix;
  };
}
