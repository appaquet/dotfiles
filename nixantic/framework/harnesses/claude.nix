_: {
  name = "claude";
  outputDir = "claude";

  tools = {
    taskCreate = "TaskCreate";
    askUserQuestion = "AskUserQuestion";
  };
  prose.questions.request = "use `AskUserQuestion`";

  renderArtifact =
    artifact:
    let
      permissionValue = if artifact.permission != null then artifact.permission else { };
      common = {
        outputPath =
          if artifact.kind == "instruction" && artifact.role == "main" then
            "CLAUDE.md"
          else if artifact.kind == "instruction" && artifact.role == "rule" then
            "rules/${artifact.key}.md"
          else if artifact.kind == "instruction" then
            "${artifact.key}.md"
          else if artifact.kind == "agent" then
            "agents/${artifact.name}.md"
          else if artifact.kind == "command" then
            "commands/${artifact.name}.md"
          else if artifact.kind == "skill" then
            "skills/${artifact.key}/SKILL.md"
          else if artifact.kind == "skillFile" then
            "skills/${artifact.skillKey}/${artifact.subPath}"
          else
            throw "Nixantic Claude renderer does not support artifact kind '${artifact.kind}'";
      };
      agent = {
        frontmatter = {
          name = artifact.name;
          description = artifact.description;
          model = artifact.model;
          effort = artifact.effort;
          tools = permissionValue.tools or null;
          disallowedTools = permissionValue.disallowedTools or null;
          permissionMode = permissionValue.permissionMode or null;
        };
        frontmatterOrder = [
          "name"
          "description"
          "model"
          "effort"
          "tools"
          "disallowedTools"
          "permissionMode"
        ];
      };
      command = {
        frontmatter = {
          name = artifact.name;
          description = artifact.description;
          "argument-hint" = artifact.argumentHint;
          model = artifact.model;
          effort = artifact.effort;
          context = artifact.context;
          agent = artifact.agent;
          "allowed-tools" = artifact.allowedTools;
        };
        frontmatterOrder = [
          "name"
          "description"
          "argument-hint"
          "model"
          "effort"
          "context"
          "agent"
          "allowed-tools"
        ];
      };
      skill = {
        frontmatter = command.frontmatter // {
          metadata = artifact.metadata;
          when_to_use = artifact.whenToUse;
          "disable-model-invocation" = artifact.disableModelInvocation;
          "user-invocable" = artifact.userInvocable;
        };
        frontmatterOrder = [
          "name"
          "description"
          "argument-hint"
          "model"
          "effort"
          "context"
          "agent"
          "allowed-tools"
          "when_to_use"
          "disable-model-invocation"
          "user-invocable"
          "metadata"
        ];
      };
    in
    common
    // (
      if artifact.kind == "instruction" || artifact.kind == "skillFile" then
        {
          frontmatter = { };
          frontmatterOrder = [ ];
        }
      else if artifact.kind == "agent" then
        agent
      else if artifact.kind == "command" then
        command
      else if artifact.kind == "skill" then
        skill
      else
        throw "Nixantic Claude renderer does not support artifact kind '${artifact.kind}'"
    );
}
