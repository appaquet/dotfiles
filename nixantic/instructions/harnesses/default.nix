/*
  A harness defines platform-specific rendering and behavior for a given AI coding agent.

  Constructors pass all authored fields to the harness. Each harness decides which fields it cares
  about and how to use them.

  For each harness, we define:
  {
    name = "platform";
    outputDir = "platform";

    tools = {
      taskCreate = "platform-task-tool";
    };

    # See `mkAgent` for full attribute list.
    renderAgentFrontmatter = { name, description, model, ... }:
      renderFrontmatter [
        { label = "name";        value = name;        }
        { label = "description"; value = description; }
        { label = "model";       value = model;       }
        ...
      ];

    # See `mkCommand` for full attribute list.
    renderCommandFrontmatter = { name, description, ... }:
      renderFrontmatter [
        { label = "name";        value = name;        }
        { label = "description"; value = description; }
        ...
      ];

    # See `mkSkill` for full attribute list.
    renderSkillFrontmatter = { name, description, ... }:
      renderFrontmatter [
        { label = "name";        value = name;        }
        { label = "description"; value = description; }
        ...
      ];
  }
*/

{ renderFrontmatter }:
{
  claude = import ./claude.nix { inherit renderFrontmatter; };
  opencode = import ./opencode.nix { inherit renderFrontmatter; };
}
