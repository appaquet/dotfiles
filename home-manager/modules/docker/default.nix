{ pkgs, ... }:

{
  programs.fish = {
    shellAbbrs = {
      d = "docker ";
      dc = "docker compose";
    };
  };

  home.packages = with pkgs; [
    dive # docker container explorer
    lazydocker # top like app for docker
  ];
}
