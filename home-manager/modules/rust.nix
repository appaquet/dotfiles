{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rustup # don't install cargo, let rustup do the job here
  ];

  programs.fish.interactiveShellInit = ''
      set -x PATH $PATH ~/.cargo/bin
  '';
}

