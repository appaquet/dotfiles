// Payload parsing and window merging for machines other than this one: the status bar reads each machine's
// `data/claude-usage/sessions` dump and merges every source. No `herdr` import lives here, so the bun check can
// load this file; `data.js` imports the app API and cannot be imported by a test.

// The windows a payload may carry. `data.js` lists the same three and cannot be imported for the reason above.
export const WINDOW_KEYS = ["five_hour", "seven_day", "spend_limit"];
export const SEPARATOR = "@@@";

// What runs on another machine: prints every payload behind SEPARATOR, so one round trip carries them all and
// nothing beyond `sh` and `cat` is needed there. The app home follows the same variable the app does, so a machine
// that moves it keeps working. `-mtime -8` matches the local prune() horizon, so a machine whose app never runs
// cannot grow the transfer.
export const sourceCommand = `d=\${HERDR_APP_HOME:-$HOME/.config/herdr-app}/data/claude-usage/sessions
for f in $(find "$d" -name '*.json' -mtime -8 2>/dev/null); do printf '\\n@@@\\n'; cat "$f"; done`;

// The scope a payload is attributed to when it carries no marker: the dump is shared by personal and scoped
// instances, and an older payload predates the marker, so it is read as the personal account.
export const DEFAULT_SCOPE = "personal";

export function scopeOf(payload) {
  const scope = payload?.scope;
  return typeof scope === "string" && scope.trim() ? scope.trim() : DEFAULT_SCOPE;
}

// The payloads a dump holds, in order. A chunk that is blank or does not parse is dropped rather than failing the
// whole read, so one truncated write on the other machine costs nothing.
export function parseDump(text) {
  if (!text) return [];

  const payloads = [];
  for (const chunk of text.split(SEPARATOR)) {
    const trimmed = chunk.trim();
    if (!trimmed) continue;

    try {
      payloads.push(JSON.parse(trimmed));
    } catch {}
  }
  return payloads;
}

// Per scope, per window, the freshest report those payloads hold. Personal and scoped instances share the dump
// but must never overwrite each other's windows.
export function windowsOf(payloads) {
  const windows = {};
  for (const payload of payloads) {
    const scope = scopeOf(payload);
    let bucket = null;
    for (const key of WINDOW_KEYS) {
      const window = payload?.rate_limits?.[key];
      if (!window || typeof window.used_percentage !== "number") continue;

      bucket ??= (windows[scope] ??= {});
      const entry = { used: window.used_percentage, resets: typeof window.resets_at === "number" ? window.resets_at : 0 };
      if (fresher(entry, bucket[key])) bucket[key] = entry;
    }
  }
  return windows;
}

// Every source's windows as one, per scope, i.e. the same rule applied across machines. A source may be empty
// or miss a window; nothing it lacks removes what another source reported. Scopes never merge into each other.
export function mergeWindows(...maps) {
  const merged = {};
  for (const map of maps) {
    for (const [scope, windows] of Object.entries(map ?? {})) {
      const bucket = (merged[scope] ??= {});
      for (const [key, entry] of Object.entries(windows)) {
        if (entry && fresher(entry, bucket[key])) bucket[key] = entry;
      }
    }
  }
  return merged;
}

// Whether `a` is the fresher report, `b` being the one it is compared against (absent means any entry wins). The
// latest window wins; inside one window usage only grows, so the greater value is the later report.
function fresher(a, b) {
  return !b || a.resets > b.resets || (a.resets === b.resets && a.used > b.used);
}
