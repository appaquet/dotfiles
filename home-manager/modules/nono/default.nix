{
  pkgs,
  ...
}:

{
  home.file = {
    ".config/nono/profiles/coding-agent.json".source = ./coding-agent.json;
  };

  home.packages = [
    pkgs.nono
  ];
}
