{
  nixantic.sources.harnesses.instructions."pi-prompts" = {
    harnesses = [ "pi" ];
    role = "rule";
    heading = "Prompt templates and skills";
    content = ''
      Pi prompt templates use `$1`, `$2`, and `$ARGUMENTS` for invocation arguments. Keep template arguments separate from shell variables.

      Nixantic renders Pi context in `AGENTS.md`, prompts under `prompts/`, and Agent Skills under `skills/<name>/SKILL.md`. Load a skill when its description matches the task; do not treat skills as prompt templates.
    '';
  };
}
