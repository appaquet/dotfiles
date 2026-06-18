{
  nixantic.sources.main.blocks."task-management" =
    { scope }:
    {
      heading = "Task management";
      content = ''
        * ALWAYS use the task tool (`${scope.harness.tools.taskCreate}`) to create tasks for any instruction step that has a 🔳 annotation, before
          executing any of the instructions
          * If you don't have access to the tool, just mention the tasks out loud and mention them as you complete them
          * Create one or more tasks per 🔳 step, 1:n mapping using the `${scope.harness.tools.taskCreate}` tool
          * No ad-hoc replacements or broader grouping
          * THEN execute the instructions & tasks in order

        * Marking in-progress/completed as you proceed, always make sure you do so and make as completed
          previous tasks if you forgot to mark them on a later step
          Never mark a task as completed before it's actually completed
      '';

      preFlightRecall = ''
        Following Task management guidelines, create tasks for 🔳 annotated instructions and strictly follow the task management guidelines for executing and completing them. No tasks is trivial enough to skip the task management process
      '';
    };
}
