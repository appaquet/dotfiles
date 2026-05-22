{ renderFrontmatter }:
{
  name = "claude";
  outputDir = "claude";
  defaultModel = "haiku";

  renderAgentFrontmatter =
    {
      name,
      description,
      model,
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
        label = "model";
        value = model;
      }
    ];

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
