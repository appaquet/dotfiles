{ pkgs, ... }:

# ^ receives arguments from home-manager, `...` allows many others

{

  imports = [
    # ./some-other-mod.nix
  ];

  # These packages will be installed in the home directory
  # Options from different modules get merged, you can add this into many files
  home.packages = with pkgs; [
    jq
    bat
  ];

  home.file."hello-world.txt".text = ''
    Hello, world!
  '';

  home.file."some-file.txt".source = ./some-file.txt;


  home.username = "mrene";
  home.homeDirectory = "/Users/mrene";

  # This makes sure that it can read the saved state that it has between runs (to remove previously installed things, for example)
  home.stateVersion = "22.11";
}

