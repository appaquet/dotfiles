{
  nixantic.sources.main.blocks."clarification-procedure" =
    { scope }:
    {
      content = "";
      tag = "clarification-procedure";

      taggedContent = ''
        * Resolve factual gaps from code, docs, prior decisions, and permitted research before asking the user. Don't reconfirm explicit decisions.
        * Use established patterns for routine, low-risk choices. State consequential assumptions rather than asking about every implementation detail.
        * Ask only for missing information or decisions that materially affect scope, behavior, risk, or user-owned trade-offs. Required approvals still apply. When needed, ${scope.harness.prose.questions.request}.
        * Group independent questions; ask sequentially only when answers depend on earlier decisions. Give brief context and a recommendation.
        * Stop clarifying when the next planned step is sufficiently defined. Report remaining uncertainty instead of inventing questions to reach certainty.
        * If project docs exist, record clarification decisions and relevant findings using ${
          scope.skills."project-docs".reference
        }.
      '';
    };
}
