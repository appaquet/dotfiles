{ renderFrontmatter }:
{
  name = "claude";
  outputDir = "claude";

  tools = {
    taskCreate = "TaskCreate";
  };

  # https://code.claude.com/docs/en/sub-agents#supported-frontmatter-fields
  # Check `mkAgent` for available options
  renderAgentFrontmatter =
    {
      name,
      description,
      model,
      effort ? null,
      permission ? null,
      ...
    }:
    let
      permissionValue = if permission != null then permission else { };
    in
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
        label = "model";
        value = model;
      }
      {
        label = "effort";
        value = effort;
      }
      {
        label = "tools";
        value = permissionValue.tools or null;
      }
      {
        label = "disallowedTools";
        value = permissionValue.disallowedTools or null;
      }
      {
        label = "permissionMode";
        value = permissionValue.permissionMode or null;
      }
    ];

  # https://code.claude.com/docs/en/skills#frontmatter-reference
  # Check `mkCommand` for available options
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
        label = "argument-hint";
        value = argumentHint;
      }
      {
        label = "model";
        value = model;
      }
      {
        label = "effort";
        value = effort;
      }
      {
        label = "context";
        value = context;
      }
      {
        label = "agent";
        value = agent;
      }
      {
        label = "allowed-tools";
        value = allowedTools;
      }
    ];

  # https://code.claude.com/docs/en/skills#frontmatter-reference
  # Check `mkSkill` for available options
  renderSkillFrontmatter =
    {
      name,
      description,
      argumentHint ? null,
      model ? null,
      effort ? null,
      context ? null,
      agent ? null,
      allowedTools ? null,
      whenToUse ? null,
      disableModelInvocation ? null,
      userInvocable ? null,
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
        label = "argument-hint";
        value = argumentHint;
      }
      {
        label = "model";
        value = model;
      }
      {
        label = "effort";
        value = effort;
      }
      {
        label = "context";
        value = context;
      }
      {
        label = "agent";
        value = agent;
      }
      {
        label = "allowed-tools";
        value = allowedTools;
      }
      {
        label = "when_to_use";
        value = whenToUse;
      }
      {
        label = "disable-model-invocation";
        value = disableModelInvocation;
      }
      {
        label = "user-invocable";
        value = userInvocable;
      }
      {
        label = "metadata";
        value = metadata;
      }
    ];
}
