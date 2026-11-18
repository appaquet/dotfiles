{
  pkgs,
  jjUtils,
  unitTest,
}:

# Exercise project-only rebases and the legacy tug against the packaged command.
pkgs.runCommand "jj-proj-tug-unit-check"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.jujutsu
      jjUtils
    ];
  }
  ''
    JJ_PROJ_TUG_BIN=${jjUtils}/bin/jj-proj-tug \
      bash ${unitTest}

    touch "$out"
  ''
