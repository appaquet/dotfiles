// Copied from github.com/PostHog/herdr (claude-usage/mods/claude-usage, rev 489f528). 
// Copyright (c) 2026 PostHog Inc., MIT license: see LICENSE.claude-usage.
import { exec, hc, home, appHome, readTextFile } from "herdr";
import * as fs from "fs/promises";
import { scopeOf } from "./sources.js";

export const dataDir = () => `${appHome()}/data/claude-usage`;
export const tapPath = () => `${appHome()}/mods/claude-usage/tap.sh`;
const CHUNK = 4 * 1024 * 1024;
const KEEP_DAYS = 8;

export const WINDOWS = [
  { key: "five_hour", label: "5h", long: "5 hours", title: "5-hour Claude limit" },
  { key: "seven_day", label: "week", long: "Week", title: "Weekly Claude limit" },
  { key: "spend_limit", label: "spend", long: "Spend", title: "Claude spend limit" },
];

const parse = (text) => {
  if (text == null || text === "") return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
};

const shq = (s) => `'${String(s).replace(/'/g, `'\\''`)}'`;

export function utf8Len(s) {
  let n = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c < 0x80) n += 1;
    else if (c < 0x800) n += 2;
    else if (c >= 0xd800 && c <= 0xdbff && i + 1 < s.length) {
      n += 4;
      i++;
    } else n += 3;
  }
  return n;
}

async function envConfigDir() {
  const r = await exec("/bin/sh", ["-c", 'printf %s "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"']).catch(() => null);
  return r?.code === 0 && r.stdout ? r.stdout : null;
}

export async function ensureDataDir() {
  await exec("/bin/sh", ["-c", 'umask 077; mkdir -p "$1/sessions" && chmod 700 "$1"', "sh", dataDir()]);
}

export async function auth() {
  try {
    const r = await exec("claude", ["auth", "status", "--json"]);
    const s = parse(r.stdout.trim());
    if (s && typeof s === "object") {
      if (!s.configDirectory) s.configDirectory = await envConfigDir();
      return s;
    }
    return { error: (r.stderr || r.stdout).trim().split("\n").pop() || `claude exited ${r.code}` };
  } catch (e) {
    return { missing: true, error: String(e?.message ?? e) };
  }
}

export const configDir = (a) => a?.configDirectory || `${home()}/.claude`;
export const projectsDir = (a) => a?.projectsDirectory || `${configDir(a)}/projects`;

const tee = () => `{ [ -f ${shq(tapPath())} ] && sh ${shq(tapPath())} --tee || cat; }`;
const opening = () => `${tee()} | {\n`;
const CLOSING = "\n}";
const tapOnly = () => `${tee()} >/dev/null`;
const legacyOpening = () => `[ -f ${shq(tapPath())} ] && exec sh ${shq(tapPath())}`;

export const wrap = (command) => (command ? `${opening()}${command}${CLOSING}` : tapOnly());

export function unwrap(command, dir) {
  if (typeof command !== "string") return null;
  const text = command.trimEnd();
  if (text === tapOnly()) return "";
  if (text.startsWith(opening()) && text.endsWith(CLOSING) && text.length > opening().length + CLOSING.length) {
    return text.slice(opening().length, -CLOSING.length);
  }
  if (text.startsWith(legacyOpening())) {
    let rest = text.slice(legacyOpening().length);
    const arg = ` ${shq(backupDir(dir))}`;
    if (rest.startsWith(arg)) rest = rest.slice(arg.length);
    if (rest.startsWith("; ")) return rest.slice(2);
  }
  return null;
}

async function legacySaved(dir) {
  const text = (await readTextFile(`${backupDir(dir)}/original-statusline.json`)) ?? (await readTextFile(`${dataDir()}/original-statusline.json`));
  return parse(text);
}

export async function connection(dir) {
  const path = `${dir}/settings.json`;
  const text = await readTextFile(path);
  const settings = text == null ? {} : parse(text);
  if (!settings || typeof settings !== "object" || Array.isArray(settings)) return { path, error: `${path} is not valid JSON` };
  const command = settings.statusLine?.command;
  const connected = typeof command === "string" && command.includes("/mods/claude-usage/tap.sh");
  let own = connected ? unwrap(command, dir) : null;
  const legacy = own != null && command.trimEnd() !== tapOnly() && !command.startsWith(opening());
  if (legacy && own === "true" && (await legacySaved(dir))?.command !== "true") own = "";
  return { path, text, settings, connected, command: own, legacy };
}

const REPLACE = [
  'src="$1"; t="$2"; new=""',
  'trap \'rm -f "$src" "$new"\' EXIT',
  'n=0',
  'while [ -L "$t" ] && [ "$n" -lt 40 ]; do',
  '  l="$(readlink "$t")"',
  '  case "$l" in /*) t="$l" ;; *) t="$(dirname "$t")/$l" ;; esac',
  '  n=$((n + 1))',
  'done',
  'new="$(mktemp "$t.XXXXXX")" || exit 1',
  'cat "$src" > "$new" || exit 1',
  'if [ -e "$t" ]; then',
  '  case "$(uname)" in Darwin) mode="$(stat -f %Lp "$t")" ;; *) mode="$(stat -c %a "$t")" ;; esac',
  '  chmod "$mode" "$new" || exit 1',
  'fi',
  'mv -f "$new" "$t"',
].join("\n");

async function writeThrough(path, before, text) {
  const now = await readTextFile(path);
  if (now !== before) throw new Error("Claude Code's settings changed while this ran. Try again.");
  await ensureDataDir();
  const tmp = `${dataDir()}/settings-${Date.now()}-${Math.random().toString(36).slice(2, 10)}.json`;
  await fs.writeFile(tmp, text);
  const r = await exec("/bin/sh", ["-c", REPLACE, "sh", tmp, path]);
  if (r.code !== 0) throw new Error(r.stderr.trim() || `Couldn't write ${path}`);
}

const pretty = (o) => `${JSON.stringify(o, null, 2)}\n`;

export const backupDir = (dir) => `${dataDir()}/configs/${String(dir).replace(/[^A-Za-z0-9_-]/g, "_")}`;

async function forgetLegacy(dir) {
  const b = backupDir(dir);
  for (const name of ["original-command", "original-statusline.json"]) await fs.unlink(`${b}/${name}`).catch(() => null);
  await fs.rmdir(b).catch(() => null);
}

export async function connect(dir) {
  const c = await connection(dir);
  if (c.error) throw new Error(c.error);
  if (c.connected) return;
  const original = c.settings.statusLine ?? null;
  const command = original?.type === "command" && typeof original.command === "string" ? original.command : "";
  const statusLine = { ...(original ?? {}), type: "command", command: wrap(original ? command || "true" : "") };
  await writeThrough(c.path, c.text, pretty({ ...c.settings, statusLine }));
}

export async function upgrade(dir) {
  const c = await connection(dir);
  if (c.error || !c.legacy) return;
  await writeThrough(c.path, c.text, pretty({ ...c.settings, statusLine: { ...c.settings.statusLine, command: wrap(c.command) } }));
  await forgetLegacy(dir);
}

export async function disconnect(dir) {
  const c = await connection(dir);
  if (c.error) throw new Error(c.error);
  if (!c.connected) return;
  if (c.command == null) throw new Error(`Your statusline command in ${c.path} no longer has the shape Connect wrote. Remove tap.sh from it by hand.`);
  const next = { ...c.settings };
  if (c.command) next.statusLine = { ...c.settings.statusLine, command: c.command };
  else delete next.statusLine;
  await writeThrough(c.path, c.text, pretty(next));
  await forgetLegacy(dir);
}

export async function clearReports() {
  await exec("find", [`${dataDir()}/sessions`, "-name", "*.json", "-delete"]).catch(() => null);
}

export async function prune() {
  await exec("find", [`${dataDir()}/sessions`, "-name", "*.json", "-mtime", `+${KEEP_DAYS}`, "-delete"]).catch(() => null);
}

export async function limits() {
  const dir = `${dataDir()}/sessions`;
  let names = [];
  try {
    names = (await fs.readdir(dir)).filter((n) => n.endsWith(".json"));
  } catch {
    return { windows: {}, sessions: new Map(), reports: 0 };
  }
  const windows = {};
  const sessions = new Map();
  for (const name of names) {
    const p = parse(await readTextFile(`${dir}/${name}`).catch(() => null));
    if (!p) continue;
    sessions.set(p.session_id ?? name.slice(0, -5), { transcript: p.transcript_path ?? null, model: p.model?.display_name ?? null });
    const scope = scopeOf(p);
    let bucket = null;
    for (const { key } of WINDOWS) {
      const w = p.rate_limits?.[key];
      if (!w || typeof w.used_percentage !== "number") continue;
      bucket ??= (windows[scope] ??= {});
      const resets = typeof w.resets_at === "number" ? w.resets_at : 0;
      const best = bucket[key];
      if (!best || resets > best.resets || (resets === best.resets && w.used_percentage > best.used)) {
        bucket[key] = { used: w.used_percentage, resets };
      }
    }
  }
  return { windows, sessions, reports: names.length };
}

export async function sessionOf(address, dir) {
  const r = await hc(["get", address, "--json"]);
  const pid = parse(r.stdout)?.foreground?.pid;
  if (!pid) return null;
  return parse(await readTextFile(`${dir}/sessions/${pid}.json`).catch(() => null))?.sessionId ?? null;
}

export async function findTranscript(dir, sid) {
  let folders = [];
  try {
    folders = await fs.readdir(dir);
  } catch {
    return null;
  }
  for (const f of folders) {
    const path = `${dir}/${f}/${sid}.jsonl`;
    if (await fs.exists(path)) return path;
  }
  return null;
}

const READ = [
  '[ -r "$1" ] || exit 3',
  'size="$(wc -c < "$1" | tr -d " ")" || exit 3',
  '[ -n "$size" ] || exit 3',
  'printf "%s\\n" "$size"',
  'tail -c +"$2" "$1" | head -c "$3"',
].join("\n");

const LINE_END = [
  'n="$(tail -c +"$2" "$1" | head -n 1 | wc -c | tr -d " ")" || exit 3',
  '[ -n "$n" ] && [ "$n" -gt 0 ] || exit 3',
  '[ "$(tail -c +"$(($2 + n - 1))" "$1" | head -c 1 | wc -l | tr -d " ")" = 1 ] || exit 4',
  'printf "%s\\n" "$n"',
].join("\n");

const fresh = () => ({ offset: 0, seen: new Set(), output: 0, input: 0, cacheRead: 0, model: null });

export class Totals {
  constructor() {
    this.files = new Map();
  }

  async of(transcript) {
    const base = transcript.replace(/\.jsonl$/, "");
    let subs = [];
    try {
      subs = (await fs.readdir(`${base}/subagents`)).filter((n) => n.endsWith(".jsonl")).map((n) => `${base}/subagents/${n}`);
    } catch {
      subs = [];
    }
    const files = [transcript, ...subs];
    const sizes = await this.sizes(files);
    const sum = { output: 0, input: 0, cacheRead: 0, model: null };
    for (const file of files) {
      const known = this.files.get(file);
      const s = known && sizes.get(file) === known.offset ? known : await this.read(file);
      sum.output += s.output;
      sum.input += s.input;
      sum.cacheRead += s.cacheRead;
      if (file === transcript) sum.model = s.model;
    }
    return sum;
  }

  async sizes(files) {
    const out = new Map();
    const r = await exec("wc", ["-c", "--", ...files]).catch(() => null);
    for (const line of (r?.stdout ?? "").split("\n")) {
      const m = /^\s*(\d+)\s+(.+)$/.exec(line);
      if (m && files.includes(m[2])) out.set(m[2], Number(m[1]));
    }
    return out;
  }

  async read(file) {
    let s = this.files.get(file);
    if (!s) {
      s = fresh();
      this.files.set(file, s);
    }
    for (let i = 0; i < 8; i++) {
      const r = await exec("/bin/sh", ["-c", READ, "sh", file, String(s.offset + 1), String(CHUNK)]).catch(() => null);
      if (!r || r.code !== 0) break;
      const cut = r.stdout.indexOf("\n");
      if (cut < 1 || !/^\d+$/.test(r.stdout.slice(0, cut))) break;
      const size = Number(r.stdout.slice(0, cut));
      const body = r.stdout.slice(cut + 1);
      if (!Number.isFinite(size)) break;
      if (size < s.offset) {
        Object.assign(s, fresh());
        continue;
      }
      if (!body) break;
      const end = body.lastIndexOf("\n");
      if (end < 0) {
        if (size - s.offset <= CHUNK) break;
        const n = await this.lineLength(file, s.offset);
        if (!n) break;
        s.offset += n;
        continue;
      }
      const text = body.slice(0, end + 1);
      s.offset += utf8Len(text);
      for (const line of text.split("\n")) this.take(s, line);
      if (s.offset >= size) break;
    }
    return s;
  }

  async lineLength(file, offset) {
    const r = await exec("/bin/sh", ["-c", LINE_END, "sh", file, String(offset + 1)]).catch(() => null);
    const n = r?.code === 0 ? Number(r.stdout.trim()) : 0;
    return Number.isInteger(n) && n > 0 ? n : 0;
  }

  take(s, line) {
    if (!line.includes('"usage"')) return;
    const r = parse(line);
    const m = r?.message;
    if (!m?.usage || m.model === "<synthetic>") return;
    const key = m.id ?? r.requestId ?? r.uuid;
    if (key) {
      if (s.seen.has(key)) return;
      s.seen.add(key);
    }
    const u = m.usage;
    s.output += u.output_tokens ?? 0;
    s.input += (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0);
    s.cacheRead += u.cache_read_input_tokens ?? 0;
    if (m.model) s.model = m.model;
  }
}

export function modelName(id, fallback) {
  const m = /claude-([a-z]+)-(\d+)(?:-(\d+))?/.exec(id ?? "");
  if (m) return m[3] ? `${m[1]} ${m[2]}.${m[3]}` : `${m[1]} ${m[2]}`;
  return (fallback ?? id ?? "").toLowerCase();
}
