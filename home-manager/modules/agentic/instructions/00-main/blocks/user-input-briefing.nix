{
  nixantic.sources.main.blocks."user-input-briefing" =
    { scope }:
    {
      content = ''
        * Assume I have seen none of this session. When you need input from me — asking a question, requesting a decision or approval, or stopping on a blocker — re-orient me first, max 10 lines:
        * Ordinary progress and completion messages do not need it; keep them short.
      '';

      tag = "user-input-briefing";

      taggedContent = ''
        * What we're working on: task and goal, one line
        * What happened since my last input: 2-4 lines
        * What you need from me and why it matters
      '';
    };
}
