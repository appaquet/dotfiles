{
  nixantic.sources.main.blocks."user-input-briefing" =
    { scope }:
    {
      content = ''
        Before asking a question, requesting approval, or stopping on a blocker, give the context needed for that decision. Assume I have not followed the session. Scale the briefing to the decision; a minor clarification needs no full recap or mandatory sections.
      '';

      tag = "user-input-briefing";

      taggedContent = ''
        * What we're working on and the goal.
        * Where things stand and what changed since my last input. Distinguish completed work from what remains.
        * The problem or decision, its practical consequences, and what you need from me.
        * Your recommendation and why, or what is still unknown if you cannot recommend a choice.
      '';
    };
}
