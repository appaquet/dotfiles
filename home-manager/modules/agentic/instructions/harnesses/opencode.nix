{ renderFrontmatter }:
{
  name = "opencode";
  outputDir = "opencode";

  tools = {
    taskCreate = "todowrite";
  };

  # Emits mode=subagent, description, and model (null ok).
  renderAgentFrontmatter =
    {
      description,
      model,
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
    ];

  # Emits description, model, agent, and subtask. Null fields omitted.
  # Compatibility fields (name, argument-hint, effort, allowed-tools) are accepted
  # but not emitted. Shared context="fork" intent renders as subtask=true.
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
        else if context == null then
          null
        else
          throw "opencode command frontmatter: unsupported context '${context}'";
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

  # Emits name, description, license, compatibility, and metadata.
  renderSkillFrontmatter =
    {
      name,
      description,
      license ? null,
      compatibility ? null,
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
        label = "license";
        value = license;
      }
      {
        label = "compatibility";
        value = compatibility;
      }
      {
        label = "metadata";
        value = metadata;
      }
    ];
}
