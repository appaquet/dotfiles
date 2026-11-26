// Folder grouping for the spaces sidebar. Spaces sharing a hyphen-separated name prefix cluster
// under one folder header, e.g. `velix-code` and `velix-docs` under `velix`, shown as `code` and
// `docs`. One level only — a space whose name is not a prefix + suffix stays top-level, and worktree
// rows follow the folder of the main row they nest under. Pure — no app imports, so bun can test
// it directly.

// The prefix and suffix around the first hyphen, or null when a name has no usable split.
export function splitName(name) {
  if (typeof name !== "string") return null;
  const i = name.indexOf("-");
  if (i < 1 || i >= name.length - 1) return null;
  return { prefix: name.slice(0, i), suffix: name.slice(i + 1) };
}

// The folder a space's name belongs to, or null when the name carries no folder.
export function foldOf(name) {
  const part = splitName(name);
  return part ? part.prefix : null;
}

// The suffix of `name` once the folder prefix is stripped, or the name itself.
export function displayNameFor(name, folder) {
  if (folder && name.startsWith(`${folder}-`)) return name.slice(folder.length + 1);
  return name;
}

// `rows` in draw order (worktree rows nested after their main), each tagged with the folder that
// contains it: mains take the prefix from their name, worktree rows follow their parent main.
export function assignFolders(rows) {
  let current = null;
  return rows.map((r) => {
    if (r.tree) return { row: r, folder: current };
    current = foldOf(r.w.name);
    return { row: r, folder: current };
  });
}

// The sidebar's display list: a folder header before its first member, then every row tagged with
// its folder and display name. A folder appears once, no matter how many runs of its members there
// are; hyphenless spaces stay plain rows in place.
export function groupFolders(rows) {
  const foldered = assignFolders(rows);
  const counts = new Map();
  for (const { folder } of foldered) if (folder) counts.set(folder, (counts.get(folder) ?? 0) + 1);
  const seen = new Set();
  const items = [];
  for (const { row, folder } of foldered) {
    if (folder && !seen.has(folder)) {
      seen.add(folder);
      items.push({ kind: "folder", name: folder, count: counts.get(folder) });
    }
    items.push({ kind: "row", row, folder, displayName: displayNameFor(row.w.name, folder) });
  }
  return items;
}

// The folder a shown space belongs to, for the auto-unfold on a jump into a folder: mains take it
// from their name, worktrees of a present main follow that main. List is the same un-grouped list
// groupRows consumed.
export function folderOfSpace(list, space) {
  const s = list.find((r) => r.w.id === space.id);
  if (!s) return null;
  if (!s.g?.linked) return foldOf(s.w.name);
  const main = list.find((r) => r.g && !r.g.linked && r.g.repo === s.g.repo);
  // No main in the list: groupRows lists this as a top-level row, so it claims its own prefix.
  return main ? foldOf(main.w.name) : foldOf(s.w.name);
}
