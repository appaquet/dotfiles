{
  nixantic.sources.main.blocks."user-input-briefing" =
    { scope }:
    {
      content = "Before asking a question, requesting approval or stopping on a blocker:";

      tag = "user-input-briefing";
      taggedContent = ''
        * Assume I'm context-switching, and require a briefing on every interaction

        * Include the following, picking the relevant items for the situation:
          * Context / what we are working on
          * What has been done, what is currently being worked on, and what remains
          * Deviations, blockers, consequences, and decisions needed
          * Recommendations with explanations and trade-offs

        * Use ${scope.blocks."communication-style".reference}
      '';
    };
}
