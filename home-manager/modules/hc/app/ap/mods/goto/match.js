// Fuzzy filter for the space picker. Pure (no herdr imports), so it can run under plain node.

// Whether every whitespace-separated word of `filter` fits, letters in order with gaps allowed, inside one of
// `names` (case-insensitive): `hcc` fits `herdr-core-config`, `dot herdr` fits ["herdr-core-config", "dotfiles"].
// An empty filter matches everything.
export function matches(filter, names) {
  const words = filter.toLowerCase().split(/\s+/).filter(Boolean);
  const lower = names.filter(Boolean).map((n) => n.toLowerCase());
  return words.every((w) => lower.some((n) => inOrder(w, n)));
}

function inOrder(word, name) {
  let at = 0;
  for (const c of name) {
    if (c === word[at]) at++;
    if (at === word.length) return true;
  }
  return false;
}
