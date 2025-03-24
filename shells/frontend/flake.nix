{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/frontend --impure
  # watch_file /home/appaquet/dotfiles/shells/frontend/flake.nix

  description = "HF frontend & e2e";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [ ];
        };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            name = "frontend";

            buildInputs = [
            ];

            packages = with pkgs; [
              protobuf
              nodejs_20
              yarn
              playwright-driver.browsers
              typescript-language-server
            ];

            shellHook = ''
              export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
              export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            '';
          };
        };
      }
    );
}
