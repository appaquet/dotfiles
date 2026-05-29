let
  main = {
    description = "Instructions to be used as soon as any instruction, CLAUDE.md/AGENTS.md, command, skill or agent file needs to be changed.";

    argumentHint = "[files or description]";
    harnesses = [ ];

    content = ''
      # Instruction Editing Router

      Thin activation skill for instruction-source edits. Route to the right layer, apply the quality bar below, load only the needed reference, then edit the authored source files.

      ## Activation Core
      - Edit authored sources, not rendered or installed markdown output.
      - Preserve important guidance; remove duplication instead of silently dropping content.
      - Prefer stable anchors and short references over copied architecture prose.
      - Read nearby sources before editing so names, constructors, and patterns stay aligned.
      - Validate with the smallest build/check that proves the changed instruction surface.

      ## Activation-Time Quality Checklist
      Before editing, identify the instruction's job in one sentence: who loads it, what decision it changes, and what failure it prevents.

      Keep or add only guidance that passes at least one test:
      - It changes agent behavior at the moment the file is loaded.
      - It states a boundary, stop condition, verification step, or output contract that would otherwise be guessed.
      - It routes to a durable source of truth that is safer than duplicating details here.

      Rewrite or delete guidance that is merely a path catalog, historical note, vague principle, or model-praise prose. If detailed guidance is still needed, keep the activation file short and move the durable decision framework into a focused reference.

      Prefer instructions with this shape:
      1. Scope/trigger: when this applies and when it does not.
      2. Load-bearing rules: boundaries, approvals, invariants, and stop points.
      3. Workflow: ordered actions with explicit validation.
      4. References: only the next files worth loading.

      ## Routing Workflow
      1. Identify the layer you are changing.
         - Reusable renderer, source contract, or product behavior: read `~/dotfiles/nixantic/CLAUDE.md`.
         - AP personal corpus or local harness wiring: read `~/dotfiles/home-manager/modules/agentic/CLAUDE.md`.

      2. Load the minimal local reference set.
         - `@references/instruction-quality.md`: durable guidance for writing useful agent instructions.
         - `@references/personal-layer.md`: AP-only paths, boundaries, and local validation workflow.

      3. Read the target source files and adjacent peers in the same owner folder.

      4. If reusable internals are in scope, follow `nixantic/CLAUDE.md` pointers to the exact code.

      5. Edit the authored source, keep references portable, and avoid duplicating subsystem docs into
         this skill unless the information must be present at activation time.

      6. Run the minimal relevant validation and inspect rendered output when the change affects
         generated instructions.
    '';
  };
in
{
  nixantic.sources.instruction-authoring.skills."mem-editing-llmed" = {
    kind = "directory";
    inherit main;

    files = {
      "references/instruction-quality.md" = {
        kind = "md";
        content = builtins.readFile ./references/instruction-quality.md;
      };
      "references/personal-layer.md" = {
        kind = "md";
        content = builtins.readFile ./references/personal-layer.md;
      };
    };
  };
}
