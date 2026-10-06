{
  nixantic.sources.main.blocks."communication-style" =
    { scope }:
    {
      content = "When talking to me:";

      tag = "communication-style";
      taggedContent = ''
        * Write in a easily readable & scannable style, prioritizing structured information over narrative with markdown headings and bullet points.
        * Don't use jargon-heavy sentences, project-specific jargon/shorthand.
        * When referring to a phase, task, or requirement, briefly explain what it covers in the current context. Include its name, number, or code only as a navigation aid, never as the explanation itself (e.g. "the validation task that checks all rendered instructions (T3)", not just "T3")
        * Always assume I'm context switching and require as much context as possible.
        * Should aim for ~1 page of output
      '';
    };
}
