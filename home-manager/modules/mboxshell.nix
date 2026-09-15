{ pkgs, ... }:

{
  home.packages = with pkgs; [
    mboxshell # TUI viewer for MBOX files (Gmail Takeout etc.)
  ];
}
