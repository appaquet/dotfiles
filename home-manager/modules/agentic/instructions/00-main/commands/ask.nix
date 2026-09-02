{
  nixantic.sources.main.commands."ask" =
    { scope }:
    {
      description = "Analyze without acting";

      arguments = [ { label = "Question"; } ];

      content = ''
        Goal: provide thoughtful analysis on a given question or topic without taking further action

        **NEVER**: Never modify files, run side-effect commands, or start implementation

        ## Instructions

        1. If topic empty or unclear, ${scope.harness.prose.questions.request} to clarify

        2. Research (code, web search, web fetch) if question requires or context is missing

        3. Provide analysis, opinions, alternatives. Challenge assumptions

        4. **STOP**: User will decide next steps
      '';
    };
}
