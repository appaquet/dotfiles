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
    let
      body = ''
        Track every 🔳-annotated instruction step as you work through it, to avoid deviating from plan/goal. Where a task tool is available, use it; otherwise keep the steps in-context.
          * One or more tasks per 🔳 step where a task tool is available (1:n; break a complex step into multiple tasks, never group multiple 🔳 steps into one). Don't skip a step just because it looks trivial.
          * Mark each in-progress/completed as you go; before moving on, check the remaining pending steps so none are forgotten, and mark a step done only when it is fully done.
      '';
      recall = ''
        Follow task management: track each 🔳 annotated instruction (a task tool where available, else in-context) and keep its status as you go. No step is trivial enough to skip.
      '';
    in
    {
      content = body;
      preFlightRecall = recall;
    };
}
