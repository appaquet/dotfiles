{
  pkgs,
  ...
}:

{
  imports = [
    ../../../nixantic/home-manager.nix
    ./claude
    ./opencode
    ../nono
  ];

  config = {
    nixantic.sourceRoots = [ ./instructions ];

    home.packages = [
      pkgs.codeburn
    ];
  };
}
