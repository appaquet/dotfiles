{ unstablePkgs, ... }:
{
  programs.jujutsu = {
    enable = true;

    package = unstablePkgs.jujutsu; # unstable cannot be installed

    # See https://github.com/jj-vcs/jj/blob/main/docs/config.md
    settings = {
      user = {
        name = "Andre-Philippe Paquet";
        email = "appaquet@gmail.com";
      };
      ui = {
        paginate = "never";
      };
    };
  };
}
