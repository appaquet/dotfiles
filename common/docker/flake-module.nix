{
  flake.modules = {
    homeManager.docker = ./home.nix;
    nixos.docker = ./nixos.nix;
  };
}
