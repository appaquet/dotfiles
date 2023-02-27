{ config, pkgs, ... }:

let
  # See https://stackoverflow.com/questions/53658303/fetchfromgithub-filter-down-and-use-as-environment-etc-file-source
  dotTmuxRepo = pkgs.fetchFromGitHub {
    owner = "gpakosz"; # https://github.com/gpakosz/.tmux
    repo = ".tmux";
    rev = "537b276d74968a72811f0779979b4e78fc7f4777";
    sha256 = "UN2424KMjP6j2hPBk/EQZtiRiNzlOrpRGtvn6TPQ3Wk=";
    stripRoot = false;
  };

  dotTmuxConfFile = builtins.readFile (dotTmuxRepo + "/.tmux-537b276d74968a72811f0779979b4e78fc7f4777/.tmux.conf");
in
{
  # gpakosz/.tmux expect its file to be at the specific place...
  home.file.".tmux.conf".text = dotTmuxConfFile;
  home.file.".tmux.conf.local".source = ./tmux.conf.local;

  programs.tmux = {
    enable = true;
    package = pkgs.tmux;

    extraConfig = ''
      source-file ~/.tmux.conf
    '';
  };
}
