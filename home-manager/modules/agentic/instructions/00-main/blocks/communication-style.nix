{
  nixantic.sources.main.blocks."communication-style" =
    { scope }:
    {
      content = "When talking to me:";

      tag = "communication-style";
      taggedContent = ''
        * Write in a easily readable & scannable style, prioritizing structured information over narrative with markdown headings and bullet points.
        * Don't use jargon-heavy sentences, project-specific jargon/shorthand.
        * Always assume I'm context switching and require as much context as possible.
        * Should aim for ~1 page of output
      '';
    };
}
