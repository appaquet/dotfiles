{
  nixantic.sources.context-management.commands."ctx-check" =
    { scope }:
    {
      description = "Analyse and output uncertainty disclosure about current task understanding";

      effort = "xhigh";

      content = ''
        Goal: analyze current task/context and output explicit uncertainty disclosure.

        **NEVER**: Never modify files, run side-effect commands, or start implementation

        ## Instructions

        1. 🔳 Review current conversation and task, and report your understanding using ${scope.blocks.context-understanding.reference}. 
              If understanding < 10/10, suggest ${scope.commands."ctx-improve".reference}.

        3. **STOP**: User will decide next steps
      '';
    };
}
