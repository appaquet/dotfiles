{
  pkgs,
  ...
}:

{
  imports = [
    ./claude
    ./opencode
    ./nono.nix
  ];

  home.packages = [
    pkgs.codeburn
  ];
}
