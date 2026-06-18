{ renderFrontmatter }:
{
  name = "opencode";
  outputDir = "opencode";

  tools = {
    taskCreate = "todowrite";
  };

  # https://opencode.ai/docs/agents/#options
  # Check `mkAgent` for available options
  renderAgentFrontmatter =
    {
      description,
      model,
      effort ? null,
      permission ? null,
      ...
    }:
    renderFrontmatter [
      {
        label = "mode";
        value = "subagent";
      }
      {
        label = "description";
        value = description;
      }
      {
        label = "model";
        value = model;
      }
      {
        label = "reasoningEffort";
        value = effort;
      }
      {
        label = "permission";
        value = permission;
      }
    ];

  # https://opencode.ai/docs/commands/#options
  # Check `mkCommand` for available options
  renderCommandFrontmatter =
    {
      description,
      model ? null,
      agent ? null,
      context ? null,
      subtask ? null,
      ...
    }:
    let
      translatedSubtask =
        if subtask != null then
          subtask
        else if context == "fork" then
          true
        else
          null;
    in
    renderFrontmatter [
      {
        label = "description";
        value = description;
      }
      {
        label = "model";
        value = model;
      }
      {
        label = "agent";
        value = agent;
      }
      {
        label = "subtask";
        value = translatedSubtask;
      }
    ];

  # https://opencode.ai/docs/commands/#options
  # Check `mkSkill` for available options
  renderSkillFrontmatter =
    {
      name,
      description,
      metadata ? null,
      ...
    }:
    renderFrontmatter [
      {
        label = "name";
        value = name;
      }
      {
        label = "description";
        value = description;
      }
      {
        label = "metadata";
        value = metadata;
      }
    ];
}
