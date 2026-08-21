_: {
  name = "opencode";
  outputDir = "opencode";
  rootFiles = {
    ".gitignore" = "";
  };

  tools = {
    taskCreate = "todowrite";
    askUserQuestion = "AskUserQuestion";
  };
  prose.questions.request = "use `AskUserQuestion`";

  renderArtifact =
    artifact:
    let
      translatedSubtask =
        if artifact.subtask != null then
          artifact.subtask
        else if artifact.context == "fork" then
          true
        else
          null;
      common = {
        outputPath =
          if artifact.kind == "instruction" && artifact.role == "main" then
            "AGENTS.md"
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
            throw "Nixantic OpenCode renderer does not support artifact kind '${artifact.kind}'";
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
        {
          frontmatter = {
            mode = "subagent";
            description = artifact.description;
            model = artifact.model;
            reasoningEffort = artifact.effort;
            permission = artifact.permission;
          };
          frontmatterOrder = [
            "mode"
            "description"
            "model"
            "reasoningEffort"
            "permission"
          ];
        }
      else if artifact.kind == "command" then
        {
          frontmatter = {
            description = artifact.description;
            model = artifact.model;
            agent = artifact.agent;
            subtask = translatedSubtask;
          };
          frontmatterOrder = [
            "description"
            "model"
            "agent"
            "subtask"
          ];
        }
      else if artifact.kind == "skill" then
        {
          frontmatter = {
            name = artifact.name;
            description = artifact.description;
            metadata = artifact.metadata;
          };
          frontmatterOrder = [
            "name"
            "description"
            "metadata"
          ];
        }
      else
        throw "Nixantic OpenCode renderer does not support artifact kind '${artifact.kind}'"
    );
}
