{
  lib,
  settings ? { },
}:

let
  adapterRegistries = import ./pi/capabilities.nix { inherit lib; };
  resolved = adapterRegistries.resolve (settings.harnesses.pi or { });
in
{
  name = "pi";
  outputDir = "pi";
  capabilities = resolved.capabilities;
  prose = resolved.prose;
  tools = {
    taskCreate = resolved.capabilities.tasks.create;
    askUserQuestion = resolved.capabilities.questions.ask;
    agentLaunch = resolved.capabilities.agents.launch;
    agentResult = resolved.capabilities.agents.result;
    agentSteer = resolved.capabilities.agents.steer;
  };

  renderArtifact =
    artifact:
    if artifact.kind == "instruction" then
      {
        outputPath =
          if artifact.role == "main" then
            "AGENTS.md"
          else if artifact.role == "rule" then
            "rules/${artifact.key}.md"
          else
            "${artifact.key}.md";
        frontmatter = { };
        frontmatterOrder = [ ];
      }
    else if artifact.kind == "agent" then
      resolved.agentAdapter.renderAgentArtifact artifact
    else if artifact.kind == "command" then
      {
        outputPath = "prompts/${artifact.name}.md";
        frontmatter = {
          description = artifact.description;
          "argument-hint" = artifact.argumentHint;
        };
        frontmatterOrder = [
          "description"
          "argument-hint"
        ];
      }
    else if artifact.kind == "skill" then
      {
        outputPath = "skills/${artifact.key}/SKILL.md";
        frontmatter = {
          name = artifact.name;
          description = artifact.description;
        };
        frontmatterOrder = [
          "name"
          "description"
        ];
      }
    else if artifact.kind == "skillFile" then
      {
        outputPath = "skills/${artifact.skillKey}/${artifact.subPath}";
        frontmatter = { };
        frontmatterOrder = [ ];
      }
    else
      throw "Nixantic Pi renderer does not support artifact kind '${artifact.kind}'";
}
