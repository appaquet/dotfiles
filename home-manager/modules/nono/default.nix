{
  pkgs,
  ...
}:

{
  home.file = {
    ".config/nono/profiles/my-default.json".source = ./my-default.json;
  };

  home.packages = [
    pkgs.nono
  ];
}
