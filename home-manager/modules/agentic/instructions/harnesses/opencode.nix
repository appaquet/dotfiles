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
      name,
      description,
      model,
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
  # Compatibility fields (name, argument-hint, effort, context, allowed-tools)
  # are accepted but not emitted.
  renderCommandFrontmatter =
    {
      name,
      description,
      argumentHint ? null,
      model ? null,
      effort ? null,
      context ? null,
      agent ? null,
      allowedTools ? null,
      subtask ? null,
    }:
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
        value = subtask;
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
