{
  nixantic.sources.main.commands."continue" = {
    description = "Continue working on the current task before being interrupted";

    onlyInjectBlockReferences = [ ];

    content = ''
      Sorry, I interrupted you. I may have pressed escape by mistake.

      Continue on what you were doing (asking questions? implementing code? reviewing code?) before being
      interrupted.
    '';
  };
}
