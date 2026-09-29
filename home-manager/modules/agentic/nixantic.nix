{ lib, ... }:

{
  nixantic = {
    versionControl.mode = lib.mkDefault "jj";
    sourceRoots = [ ./instructions ];

    instructions = {
      postProcess = true;
      bom = { };
      harnesses = {
        claude.rules.output = "files";
        opencode.rules.output = "files";
        pi = {
          rules.output = "files";
          agents = "tintinweb";
          tasks = "none";
          questions = "rpiv-ask-user-question";
        };
      };
    };
  };
}
