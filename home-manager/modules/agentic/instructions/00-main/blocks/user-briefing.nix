{
  nixantic.sources.main.blocks."user-briefing" =
    { scope }:
    {
      content = "Assume I'm context-switching: brief me before I give input and debrief me after you finish work:";

      tag = "user-briefing";
      taggedContent = ''
        * Briefing, before asking a question, requesting approval or stopping on a blocker. Pick the relevant items for the situation:
          * Context / what we are working on
          * What has been done, what is currently being worked on, and what remains
          * Deviations, blockers, consequences, and decisions needed
          * Recommendations with explanations and trade-offs

        * Debriefing, after completing work:
          * What you did, learned and deviations from plan
          * Any blockers
          * Expected next steps

        * Use ${scope.blocks."communication-style".reference}
      '';
    };
}
