{
  flake.modules = {
    homeManager.dev = ./home.nix;
    nixos.dev = ./nixos.nix;
  };
}
