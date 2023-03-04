{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rustup # don't install cargo, let rustup do the job here
  ];

  home.sessionPath = [ "~/.cargo/bin" ];
}

