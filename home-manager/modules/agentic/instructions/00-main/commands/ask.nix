{
  nixantic.sources.main.commands."ask" =
    { scope }:
    {
      description = "Analyze without acting";

      argumentHint = "[question]";

      content = ''
        Goal: provide thoughtful analysis on a given question or topic without taking further action

        **NEVER**: Never modify files, run side-effect commands, or start implementation

        ## Instructions

        1. If topic empty or unclear, use `AskUserQuestion` to clarify

        2. 🔳 Research (code, web search, web fetch) if question requires or context is missing
           * You need to use sub-agents to explore or read codebase, do research, etc.
             Your context is precious, don't waste it
           * Analyze thoroughly
           * Apply ${scope.blocks.deep-thinking.reference} procedure

        3. 🔳 Provide analysis, opinions, alternatives. Challenge assumptions

        4. **STOP**: User will decide next steps
      '';
    };
}
