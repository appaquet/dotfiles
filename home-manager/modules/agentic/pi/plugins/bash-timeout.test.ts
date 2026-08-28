import * as assert from "node:assert/strict";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { test, beforeEach, afterEach } from "node:test";
import {
  CONFIG_FILE_NAME,
  FALLBACK_CONFIG,
  loadTimeoutConfig,
  parseTimeoutConfig,
  resolveTimeoutPolicy,
} from "./bash-timeout.ts";

let agentDir = "";

beforeEach(() => {
  agentDir = fs.mkdtempSync(path.join(os.tmpdir(), "bash-timeout-test-"));
});

afterEach(() => {
  fs.rmSync(agentDir, { recursive: true, force: true });
});

function writeConfig(obj: unknown): void {
  fs.writeFileSync(
    path.join(agentDir, CONFIG_FILE_NAME),
    JSON.stringify(obj),
    "utf8",
  );
}

// ---------------------------------------------------------------------------
// parseTimeoutConfig
// ---------------------------------------------------------------------------

test("parse: valid config resolves exact values", () => {
  assert.deepEqual(parseTimeoutConfig('{"defaultTimeoutSeconds":300,"maxTimeoutSeconds":1200}'), {
    defaultTimeoutSeconds: 300,
    maxTimeoutSeconds: 1200,
  });
});

test("parse: non-default pair proves the file is used", () => {
  assert.deepEqual(parseTimeoutConfig('{"defaultTimeoutSeconds":60,"maxTimeoutSeconds":600}'), {
    defaultTimeoutSeconds: 60,
    maxTimeoutSeconds: 600,
  });
});

test("parse: default equals max is valid", () => {
  assert.deepEqual(parseTimeoutConfig('{"defaultTimeoutSeconds":300,"maxTimeoutSeconds":300}'), {
    defaultTimeoutSeconds: 300,
    maxTimeoutSeconds: 300,
  });
});

for (const [label, raw] of [
  ["empty string", ""],
  ["malformed JSON", "{not valid json"],
  ["array", "[1,2,3]"],
  ["string", '"hello"'],
  ["number", "42"],
  ["null", "null"],
] as const) {
  test(`parse: ${label} falls back`, () => {
    assert.deepEqual(parseTimeoutConfig(raw), FALLBACK_CONFIG);
  });
}

test("parse: missing default field falls back", () => {
  assert.deepEqual(parseTimeoutConfig('{"maxTimeoutSeconds":1200}'), FALLBACK_CONFIG);
});

test("parse: missing max field falls back", () => {
  assert.deepEqual(parseTimeoutConfig('{"defaultTimeoutSeconds":300}'), FALLBACK_CONFIG);
});

test("parse: string default falls back", () => {
  assert.deepEqual(
    parseTimeoutConfig('{"defaultTimeoutSeconds":"300","maxTimeoutSeconds":1200}'),
    FALLBACK_CONFIG,
  );
});

test("parse: boolean max falls back", () => {
  assert.deepEqual(
    parseTimeoutConfig('{"defaultTimeoutSeconds":300,"maxTimeoutSeconds":true}'),
    FALLBACK_CONFIG,
  );
});

test("parse: null field value falls back", () => {
  assert.deepEqual(
    parseTimeoutConfig('{"defaultTimeoutSeconds":null,"maxTimeoutSeconds":1200}'),
    FALLBACK_CONFIG,
  );
});

test("parse: fractional limit falls back", () => {
  assert.deepEqual(
    parseTimeoutConfig('{"defaultTimeoutSeconds":3.5,"maxTimeoutSeconds":1200}'),
    FALLBACK_CONFIG,
  );
});

test("parse: zero default falls back", () => {
  assert.deepEqual(
    parseTimeoutConfig('{"defaultTimeoutSeconds":0,"maxTimeoutSeconds":1200}'),
    FALLBACK_CONFIG,
  );
});

test("parse: negative default falls back", () => {
  assert.deepEqual(
    parseTimeoutConfig('{"defaultTimeoutSeconds":-1,"maxTimeoutSeconds":1200}'),
    FALLBACK_CONFIG,
  );
});

test("parse: zero max falls back", () => {
  assert.deepEqual(
    parseTimeoutConfig('{"defaultTimeoutSeconds":300,"maxTimeoutSeconds":0}'),
    FALLBACK_CONFIG,
  );
});

test("parse: default above max falls back", () => {
  assert.deepEqual(
    parseTimeoutConfig('{"defaultTimeoutSeconds":2000,"maxTimeoutSeconds":1000}'),
    FALLBACK_CONFIG,
  );
});

// ---------------------------------------------------------------------------
// loadTimeoutConfig (file-backed)
// ---------------------------------------------------------------------------

test("load: missing file uses fallback", () => {
  assert.deepEqual(loadTimeoutConfig(agentDir), FALLBACK_CONFIG);
});

test("load: valid file resolves exact values", () => {
  writeConfig({ defaultTimeoutSeconds: 60, maxTimeoutSeconds: 600 });
  assert.deepEqual(loadTimeoutConfig(agentDir), {
    defaultTimeoutSeconds: 60,
    maxTimeoutSeconds: 600,
  });
});

test("load: malformed file uses fallback", () => {
  fs.writeFileSync(path.join(agentDir, CONFIG_FILE_NAME), "{broken", "utf8");
  assert.deepEqual(loadTimeoutConfig(agentDir), FALLBACK_CONFIG);
});

test("load: invalid file (default > max) uses fallback", () => {
  writeConfig({ defaultTimeoutSeconds: 5000, maxTimeoutSeconds: 1000 });
  assert.deepEqual(loadTimeoutConfig(agentDir), FALLBACK_CONFIG);
});

// ---------------------------------------------------------------------------
// resolveTimeoutPolicy
// ---------------------------------------------------------------------------

test("policy: omitted timeout mutates to default", () => {
  assert.deepEqual(resolveTimeoutPolicy(FALLBACK_CONFIG, undefined), {
    action: "mutate",
    timeout: 300,
  });
});

test("policy: call with no timeout argument mutates to default", () => {
  assert.deepEqual(resolveTimeoutPolicy(FALLBACK_CONFIG), {
    action: "mutate",
    timeout: 300,
  });
});

test("policy: finite positive below max preserves", () => {
  assert.deepEqual(resolveTimeoutPolicy(FALLBACK_CONFIG, 60), { action: "preserve" });
});

test("policy: value just below max preserves", () => {
  assert.deepEqual(resolveTimeoutPolicy(FALLBACK_CONFIG, 1199), { action: "preserve" });
});

test("policy: value at max preserves", () => {
  assert.deepEqual(resolveTimeoutPolicy(FALLBACK_CONFIG, 1200), { action: "preserve" });
});

test("policy: value above max blocks, naming value and max", () => {
  assert.deepEqual(resolveTimeoutPolicy(FALLBACK_CONFIG, 1500), {
    action: "block",
    reason:
      "Bash timeout 1500s exceeds the 1200s ceiling. Reduce to at most 1200 seconds.",
  });
});

test("policy: far above max blocks", () => {
  assert.deepEqual(resolveTimeoutPolicy(FALLBACK_CONFIG, 999999), {
    action: "block",
    reason:
      "Bash timeout 999999s exceeds the 1200s ceiling. Reduce to at most 1200 seconds.",
  });
});

for (const value of [0, -5, NaN, Infinity, -Infinity]) {
  test(`policy: invalid value ${String(value)} blocks with an actionable reason`, () => {
    const result = resolveTimeoutPolicy(FALLBACK_CONFIG, value);
    assert.equal(result.action, "block");
    if (result.action !== "block") throw new Error("expected block");
    assert.match(result.reason, /not a valid positive finite number of seconds/);
    assert.match(result.reason, /Use a value between 1 and 1200 seconds/);
  });
}

test("policy: custom config uses its own default and ceiling", () => {
  const config = { defaultTimeoutSeconds: 60, maxTimeoutSeconds: 600 };
  assert.deepEqual(resolveTimeoutPolicy(config, undefined), {
    action: "mutate",
    timeout: 60,
  });
  assert.deepEqual(resolveTimeoutPolicy(config, 600), { action: "preserve" });
  assert.deepEqual(resolveTimeoutPolicy(config, 601), {
    action: "block",
    reason: "Bash timeout 601s exceeds the 600s ceiling. Reduce to at most 600 seconds.",
  });
});
