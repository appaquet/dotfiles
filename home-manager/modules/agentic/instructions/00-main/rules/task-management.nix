{
  nixantic.sources.main.instructions."task-management" =
    { scope }:
    {
      role = "rule";
      heading = "Task management";
      content = ''
        ${scope.blocks."task-management".embed}
      '';
    };

  nixantic.sources.main.blocks."task-management" =
    { scope }:
    {
      content = ''
        Use task tools where available to track clear goals — especially multi-turn or long-running work (implementation phases, plans, reviews). One task per goal; group fine-grained sub-steps under their step. Don't create tasks merely because steps are numbered; track short checklists in-context instead
          * Complete every numbered step of an instruction, even ones that look like bookkeeping, and sweep the remaining steps before stopping
          * Mark each task in-progress/completed as you go, and mark a task done only when it is fully done
      '';

      preFlightContent = ''
        Follow task management: use task tools for clear, especially long-running goals, and complete every numbered step. No step is trivial enough to skip.
      '';
    };
}
