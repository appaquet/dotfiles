/*
  Harness contract — what every harness must provide.

  A harness defines platform-specific frontmatter rendering for a given AI coding agent.
  Constructors (mkAgent, mkSkill, mkCommand) pass all authored fields to the harness;
  each harness selects which to emit. Null fields are omitted by the shared frontmatter
  renderer. Unrecognized fields are silently ignored.

  {
    name = "platform";
    outputDir = "platform";

    tools = {
      taskCreate = "platform-task-tool";
    };

    # Emits name, description, and model (null ok).
    renderAgentFrontmatter = { name, description, model }:
      renderFrontmatter [
        { label = "name";        value = name;        }
        { label = "description"; value = description; }
        { label = "model";       value = model;       }
      ];

    # All fields optional except name and description. Null fields omitted.
    renderCommandFrontmatter = { name, description, ... }:
      renderFrontmatter [
        { label = "name";        value = name;        }
        { label = "description"; value = description; }
        ...
      ];

    # Null fields omitted. Each harness selects its relevant subset.
    renderSkillFrontmatter = { name, description, ... }:
      renderFrontmatter [
        { label = "name";        value = name;        }
        { label = "description"; value = description; }
        ...
      ];
  }

  Documentation only — not imported. Harnesses are imported individually as
  claude.nix / opencode.nix. This empty expression keeps the file valid Nix.
*/

{ }
