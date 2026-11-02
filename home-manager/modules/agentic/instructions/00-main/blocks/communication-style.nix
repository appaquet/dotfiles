{
  nixantic.sources.main.blocks."communication-style" =
    { scope }:
    {
      content = "When talking to me:";

      tag = "communication-style";
      taggedContent = ''
        * Write in a easily readable & scannable style, prioritizing structured information over narrative with markdown headings and bullet points.

        * Don't use jargon-heavy sentences, project-specific jargon/shorthand. 
          * Ask yourself: would someone outside of the project understand this? if not, explain in plain language, introduce necessary jargon, etc.

        * When referring to a phase, task, or requirement, briefly explain what it covers in the current context. Include its name, number, or code only as a navigation aid, never as the explanation itself (e.g. "the validation task that checks all rendered instructions (T3)", not just "T3")

        * Always assume I'm context switching and require as much context as possible. Don't assume I remember what we were working on.

        * Never drown me in wall of text. Should aim for ~1 page of output.
      '';
    };
}
