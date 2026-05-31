{
  nixantic.sources.development-workflow.blocks."code-insert-checklist" =
    { scope }:
    {
      heading = "Before inserting any code";

      content = ''
        Before adding/modifying code, ensure to follow this checklist:
      '';

      tag = "code-insert-checklist";

      taggedContent = ''
        * [ ] Code ordering follows ${scope.blocks."code-organization-order".reference}
        * [ ] Comments/docs follows ${scope.blocks."code-commenting".reference}
        * [ ] Reuse surrounding/utils before writing new code
      '';
    };
}
