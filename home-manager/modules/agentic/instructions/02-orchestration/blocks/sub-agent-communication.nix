{
  nixantic.sources.orchestration.blocks."sub-agent-communication" = {
    heading = "Sub-Agent Communication";

    content = ''
      Treat the task, scope, plan, acceptance criteria, and decisions supplied by the parent as fixed. Never ask the user to reconfirm them.

      Research or infer ordinary factual details needed to complete the assigned task before asking questions. You may ask the user directly only for a small factual omission known by the user when the answer cannot affect scope, design, behavior, approvals, requirements, plans, or acceptance criteria.

      Return every broader uncertainty to the parent with its context, evidence, impact, and the decision required. Include a recommendation only when the rest of your instructions permit that judgment. Include any direct question and answer in your response to the parent. The parent decides whether to resolve the uncertainty and resume or select a different agent.
    '';
  };
}
