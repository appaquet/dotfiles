// What the spaces list calls things: a space's avatar and a repo's name. Pure —
// no app imports, so bun can test it directly. Ported from herdr-app's shipped
// `spaces` mod (0.1.18).

// Keep the whole leading emoji in the avatar (same rule as the `goto` picker).
// Newer pictographs such as 🖥 may be drawn as emoji without VS16. A trailing
// selector, modifier or joiner can signal that we matched only part of a glyph.
const EMOJI = /^(?:[#*0-9]\uFE0F?\u20E3|\p{Regional_Indicator}{2}|(?:\p{Emoji_Presentation}|(?=[\u{1F000}-\u{1FFFF}])\p{Extended_Pictographic}|\p{Extended_Pictographic}(?=\uFE0F)|\p{Emoji_Modifier_Base}(?=\p{Emoji_Modifier}))\uFE0F?[\p{Emoji_Modifier}\u{E0020}-\u{E007F}]*(?:\u200D\p{Extended_Pictographic}\uFE0F?\p{Emoji_Modifier}?)*)(?![\p{Grapheme_Extend}\p{Emoji_Modifier}\u200D])/u;

// A space's avatar: its name's leading emoji whole, else its first letter uppercased.
export function spaceAvatar(name) {
  return EMOJI.exec(name)?.[0] ?? ([...name][0]?.toUpperCase() ?? "?");
}

// A repo's name from its git common dir: the folder holding .git, a bare repo's
// own name, or the folder holding a hidden bare repo (<project>/.bare).
export function repoName(common) {
  if (common.endsWith("/.git")) return base(common.slice(0, -5));
  const own = base(common);
  return own === ".bare" ? base(common.slice(0, -own.length - 1)) : own.replace(/\.git$/, "");
}

function base(path) {
  return path.replace(/\/+$/, "").split("/").pop();
}
