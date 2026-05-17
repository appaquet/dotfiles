{
  pkgs,
  ...
}:

{
  imports = [
    ./claude
    ./opencode
    ./nono
  ];

  home.packages = [
    pkgs.codeburn
  ];
}
