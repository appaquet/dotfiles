{
  nixantic.sources.main.blocks."problem-solving" = {
    heading = "Problem Solving";

    content = ''
      ALWAYS use this methodology to solve problems, issues, and bugs:
    '';

    tag = "problem-solving-checklist";

    taggedContent = ''
      1. Understand WHY (trace data flow, logging, changes)
      2. Fix root cause, not symptom. Generic solution over specific case and bespoke fixes
      3. Ask user before destructive changes
      4. Test bugs: verify new test catches issue or update existing test to catch it
      5. Document investigation: capture uncertainty, what was tried, what was learned in phase doc
         Questions & Investigations Use a SR&ED documentation style to capture learnings and prevent going
         in circles
    '';
  };
}
