{ pkgs, ... }:

{
  home.packages = with pkgs; [
    libtree # recursive ldd 
    mold-wrapped
  ];
}
