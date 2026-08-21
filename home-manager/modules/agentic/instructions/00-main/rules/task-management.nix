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
        ALWAYS use the task tool (`${scope.harness.tools.taskCreate}`) to create tasks for any instruction step that has a 🔳 annotation, before executing any of the instructions to avoid deviating from plan/goal
          * Create one or more tasks per 🔳 step, 1:n mapping using the `${scope.harness.tools.taskCreate}` tool. If you think a step is too complex, break it down into multiple tasks. But never group multiple 🔳 steps into a single task.
          * NEVER skip task creation because of triviality.
          * If tool unavailable, just mention tasks out loud and mention them as you complete them.
          * Mark them in-progress/completed as you proceed. Always check all pending tasks in case we forgot to mark them. Never mark complete before done.
      '';

      preFlightRecall = ''
        Follow task management, create tasks for each 🔳 annotated instructions, follow guidelines status tracking. No task trivial enough.
      '';
    };
}
