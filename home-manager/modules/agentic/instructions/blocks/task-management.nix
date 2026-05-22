{ scope }:
{
  heading = "Task management";
  content = ''
    * ALWAYS use the Task tool to create tasks for any instruction step that has a 🔳 annotation, before
      executing any of the instructions
      * Create one or more tasks per 🔳 step, 1:n mapping using the `${scope.harness.tools.taskCreate}` tool
      * No ad-hoc replacements or broader grouping
      * THEN execute the instructions & tasks in order

    * Marking in-progress/completed as you proceed, always make sure you do so and make as completed
      previous tasks if you forgot to mark them on a later step
      Never mark a task as completed before it's actually completed
  '';
}
