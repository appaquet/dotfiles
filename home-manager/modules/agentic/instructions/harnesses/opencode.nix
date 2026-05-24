{ renderFrontmatter }:
{
  name = "opencode";
  outputDir = "opencode";
  defaultModel = "anthropic/claude-haiku-4.5";

  tools = {
    taskCreate = "todowrite";
  };

  # Agent frontmatter recognized by opencode:
  # - mode: "subagent" (required by our system; opencode docs: primary, subagent, all)
  # - description: shown when selecting subagents
  # - model: model to use, opencode format "provider/model-name"
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

  # Command frontmatter recognized by opencode (per opencode docs):
  # - description: shown in TUI when typing the command
  # - model: override default model for this command
  # - agent: which agent should execute (defaults to current agent)
  # - subtask: force subagent invocation (default false)
  #
  # Compatibility-only (not recognized by opencode; NOP / ignored):
  # - name: filename determines command name in opencode, not frontmatter
  # - argument-hint: Claude Code concept, no opencode equivalent
  # - effort: Claude Code concept, no opencode equivalent
  # - context: Claude Code concept, no opencode equivalent
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
