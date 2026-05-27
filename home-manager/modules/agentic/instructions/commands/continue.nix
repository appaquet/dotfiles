{ scope }:
{
  description = "Continue working on the current task before being interrupted";

  noInjectPreFlight = true;

  content = ''
    Sorry, I interrupted you. I may have pressed escape by mistake.

    Continue on what you were doing (asking questions? implementing code? reviewing code?) before being
    interrupted.
  '';
}
