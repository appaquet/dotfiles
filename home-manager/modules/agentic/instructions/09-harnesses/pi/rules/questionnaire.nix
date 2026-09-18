{
  nixantic.sources.harnesses.instructions."pi-questionnaire" =
    { scope }:
    {
      harnesses = [ "pi" ];
      role = "rule";
      heading = "Interactive questions";
      content = ''
        Use `${scope.harness.tools.askUserQuestion}`.

        Question `header` MUST be 12 characters or fewer, use `label` for explanation.
        Question `label` MUST be 50 characters or fewer.

        The questionnaire is the decision surface, not the context. All orientation goes in the message immediately before the tool call, using the ${
          scope.blocks."user-input-briefing".reference
        } block from the main instructions.

        Question text, option labels, and descriptions must be self-contained plain language that someone who never saw this project could understand. Translate glossary and domain terms; never rely on the user having read the code, docs, or earlier messages.
      '';
    };
}
