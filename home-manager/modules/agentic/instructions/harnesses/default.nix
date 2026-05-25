/*
  Harness contract — what every harness must provide.

  A harness defines platform-specific frontmatter rendering for a given AI coding agent.
  Constructors (mkAgent, mkSkill, mkCommand) pass all authored fields to the harness;
  each harness selects which to emit. Null fields are omitted by the shared frontmatter
  renderer. Unrecognized fields are silently ignored.

  Required attributes:
    name         - harness identifier, matches harness directory name
    outputDir    - top-level directory name for generated output
    tools        - platform-specific tool name overrides
    renderAgentFrontmatter    — { name, description, model }
    renderCommandFrontmatter  — { name, description, argumentHint?, model?, effort?,
                                  context?, agent?, allowedTools?, subtask? }
    renderSkillFrontmatter    — { name, description, argumentHint?, model?, effort?,
                                  context?, agent?, allowedTools?, whenToUse?,
                                  disableModelInvocation?, userInvocable?, license?,
                                  compatibility?, metadata? }

  Example harness layout (commented — not executable):
*/

# {
#   name = "platform";
#   outputDir = "platform";
#
#   tools = {
#     taskCreate = "platform-task-tool";
#   };
#
#   # Emits name, description, and model (null ok).
#   renderAgentFrontmatter = { name, description, model }:
#     renderFrontmatter [
#       { label = "name";        value = name;        }
#       { label = "description"; value = description; }
#       { label = "model";       value = model;       }
#     ];
#
#   # All fields optional except name and description. Null fields omitted.
#   renderCommandFrontmatter = { name, description, ... }:
#     renderFrontmatter [
#       { label = "name";        value = name;        }
#       { label = "description"; value = description; }
#       ...
#     ];
#
#   # Null fields omitted. Each harness selects its relevant subset.
#   renderSkillFrontmatter = { name, description, ... }:
#     renderFrontmatter [
#       { label = "name";        value = name;        }
#       { label = "description"; value = description; }
#       ...
#     ];
# }
