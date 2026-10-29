import { describe, expect, test } from "bun:test";

import {
  createComment,
  createCommentId,
  formatExport,
  isExcludedNode,
  normalizeDraft,
  normalizeRecord,
  readDraft,
  resolveTarget,
} from "./show-me-feedback.js";

// Minimal stand-ins for the DOM nodes the model inspects: an element's parent
// chain, its tag name, and its data attributes are all the resolution needs.
function element(tagName = "DIV", attributes = {}) {
  return { nodeType: 1, tagName, dataset: attributes.dataset ?? {}, parentElement: null };
}

function textNode(parent) {
  return { nodeType: 3, parentElement: parent };
}

function nest(parent, ...children) {
  for (const child of children) child.parentElement = parent;
  return parent;
}

function registered(...targets) {
  return new Map(targets.map((target) => [target.element, target]));
}

describe("comment identifiers", () => {
  test("stay distinct when created in the same millisecond", () => {
    const ids = new Set();
    for (let index = 0; index < 200; index += 1) {
      ids.add(createCommentId(() => 1_760_000_000_000, () => 0.5));
    }
    expect(ids.size).toBe(200);
  });

  test("encode the creation time", () => {
    const id = createCommentId(() => 1_760_000_000_000, () => 0);
    expect(id.startsWith(`smfb-${(1_760_000_000_000).toString(36)}-`)).toBe(true);
  });
});

describe("comment records", () => {
  test("carry the schema version and every identity field", () => {
    const record = createComment({
      id: "smfb-1",
      targetId: "guide.md#install",
      targetLabel: "Installation",
      sourceId: "guide.md",
      sourceLabel: "docs/guide.md",
      quote: "Run the installer",
      prefix: "Before you start,",
      suffix: "then reboot",
      comment: "Which installer version?",
      createdAt: 1_760_000_000_000,
    });

    expect(record).toEqual({
      v: 1,
      id: "smfb-1",
      sourceId: "guide.md",
      sourceLabel: "docs/guide.md",
      targetId: "guide.md#install",
      targetLabel: "Installation",
      quote: "Run the installer",
      prefix: "Before you start,",
      suffix: "then reboot",
      comment: "Which installer version?",
      createdAt: 1_760_000_000_000,
    });
  });

  test("keep an empty quote for whole-section comments", () => {
    const record = createComment({
      id: "smfb-2",
      targetId: "guide.md",
      targetLabel: "Guide",
      sourceId: "guide.md",
      sourceLabel: "guide.md",
      comment: "This section needs an example.",
      createdAt: 1,
    });

    expect(record.quote).toBe("");
    expect(record.prefix).toBe("");
    expect(record.suffix).toBe("");
  });
});

describe("target resolution", () => {
  const root = element("MAIN");
  const rollout = element("DIV");
  const rollback = element("DIV");
  const rolloutParagraph = element("P");
  const rollbackParagraph = element("P");
  nest(root, rollout, rollback);
  nest(rollout, rolloutParagraph);
  nest(rollback, rollbackParagraph);

  const targets = [
    { id: "notes#rollout", element: rollout },
    { id: "notes#rollback", element: rollback },
  ];
  const byElement = registered(...targets);

  test("returns the target holding both endpoints", () => {
    const start = textNode(rolloutParagraph);
    const end = textNode(rolloutParagraph);
    expect(resolveTarget(start, end, { root, byElement })?.id).toBe("notes#rollout");
  });

  test("accepts a backward selection inside one target", () => {
    const start = textNode(rolloutParagraph);
    const end = textNode(rollout);
    expect(resolveTarget(start, end, { root, byElement })?.id).toBe("notes#rollout");
  });

  test("rejects a selection spanning two targets", () => {
    const start = textNode(rolloutParagraph);
    const end = textNode(rollbackParagraph);
    expect(resolveTarget(start, end, { root, byElement })).toBeNull();
  });

  test("rejects a selection outside the annotated root", () => {
    const outside = element("P");
    const start = textNode(rolloutParagraph);
    expect(resolveTarget(start, textNode(outside), { root, byElement })).toBeNull();
  });

  test("rejects a selection with no registered target", () => {
    const plain = element("P");
    nest(root, plain);
    expect(resolveTarget(textNode(plain), textNode(plain), { root, byElement })).toBeNull();
  });

  test("rejects a selection reaching into component chrome", () => {
    const drawer = element("ASIDE", { dataset: { smfbUi: "" } });
    const drawerParagraph = element("P");
    nest(drawer, drawerParagraph);
    nest(root, drawer);
    const start = textNode(rolloutParagraph);
    expect(resolveTarget(start, textNode(drawerParagraph), { root, byElement })).toBeNull();
  });

  test("rejects a selection reaching into a form field", () => {
    const field = element("TEXTAREA");
    const fieldText = textNode(field);
    nest(rollout, field);
    const start = textNode(rolloutParagraph);
    expect(resolveTarget(start, fieldText, { root, byElement })).toBeNull();
  });

  test("returns nothing without a root or registered targets", () => {
    const node = textNode(rolloutParagraph);
    expect(resolveTarget(node, node, { root: null, byElement })).toBeNull();
    expect(resolveTarget(node, node, { root, byElement: null })).toBeNull();
  });
});

describe("excluded nodes", () => {
  test("treat component chrome and form controls as unannotatable", () => {
    expect(isExcludedNode(element("DIV", { dataset: { smfbUi: "" } }))).toBe(true);
    for (const tagName of ["BUTTON", "INPUT", "OPTION", "SELECT", "TEXTAREA"]) {
      expect(isExcludedNode(element(tagName))).toBe(true);
    }
  });

  test("allow ordinary host content", () => {
    expect(isExcludedNode(element("P"))).toBe(false);
    expect(isExcludedNode(element("CODE"))).toBe(false);
  });
});

function record(overrides = {}) {
  return createComment({
    id: "smfb-1",
    sourceId: "guide.md",
    sourceLabel: "docs/guide.md",
    targetId: "guide.md#install",
    targetLabel: "Installation",
    quote: "Run the installer",
    comment: "Which version?",
    createdAt: 1,
    ...overrides,
  });
}

describe("export formatting", () => {
  test("groups by source with section labels, quotes, and comments", () => {
    const text = formatExport([
      record({ id: "a" }),
      record({ id: "b", quote: "", comment: "Add an example." }),
      record({
        id: "c",
        sourceId: "api.md",
        sourceLabel: "docs/api.md",
        targetId: "api.md",
        targetLabel: "docs/api.md",
        quote: "line one\nline two",
        comment: "Two lines.",
      }),
    ]);

    expect(text).toBe(
      [
        "Feedback",
        "",
        "## docs/guide.md (guide.md)",
        "",
        "### Installation",
        "",
        "> Run the installer",
        "",
        "Which version?",
        "",
        "### Installation",
        "",
        "Add an example.",
        "",
        "## docs/api.md (api.md)",
        "",
        "> line one",
        "> line two",
        "",
        "Two lines.",
        "",
      ].join("\n"),
    );
  });

  test("omits the section heading when it repeats the source label", () => {
    const text = formatExport([
      record({
        sourceId: "api.md",
        sourceLabel: "api.md",
        targetId: "api.md",
        targetLabel: "api.md",
        quote: "",
        comment: "Whole document note.",
      }),
    ]);

    expect(text).toBe(
      ["Feedback", "", "## api.md", "", "Whole document note.", ""].join("\n"),
    );
  });

  test("keeps insertion order of sources and comments", () => {
    const text = formatExport([
      record({ id: "1", sourceId: "z.md", sourceLabel: "z.md", targetId: "z.md", targetLabel: "z.md", quote: "", comment: "first" }),
      record({ id: "2", sourceId: "a.md", sourceLabel: "a.md", targetId: "a.md", targetLabel: "a.md", quote: "", comment: "second" }),
      record({ id: "3", sourceId: "z.md", sourceLabel: "z.md", targetId: "z.md", targetLabel: "z.md", quote: "", comment: "third" }),
    ]);

    expect(text).toBe(
      [
        "Feedback",
        "",
        "## z.md",
        "",
        "first",
        "",
        "third",
        "",
        "## a.md",
        "",
        "second",
        "",
      ].join("\n"),
    );
  });

  test("returns a header when there is nothing to export", () => {
    expect(formatExport([])).toBe("Feedback\n");
  });
});

describe("record validation", () => {
  test("round-trips a complete record", () => {
    const original = record();
    expect(normalizeRecord(original)).toEqual(original);
  });

  test("fills absent optional context", () => {
    const stored = record();
    delete stored.quote;
    delete stored.prefix;
    delete stored.suffix;
    expect(normalizeRecord(stored)).toEqual(record({ quote: "" }));
  });

  test("rejects unusable entries", () => {
    expect(normalizeRecord(null)).toBeNull();
    expect(normalizeRecord({ ...record(), v: 2 })).toBeNull();
    expect(normalizeRecord({ ...record(), comment: "" })).toBeNull();
    expect(normalizeRecord({ ...record(), sourceId: 7 })).toBeNull();
    expect(normalizeRecord({ ...record(), createdAt: "1" })).toBeNull();
    expect(normalizeRecord({ ...record(), quote: null })).toBeNull();
    expect(normalizeRecord({ ...record(), targetId: undefined })).toBeNull();
  });
});

describe("draft validation", () => {
  test("keeps valid entries and drops the rest", () => {
    const draft = { v: 1, comments: [record({ id: "keep" }), { id: "bad" }, null] };
    expect(normalizeDraft(draft).map((entry) => entry.id)).toEqual(["keep"]);
  });

  test("rejects unsupported or malformed payloads", () => {
    expect(normalizeDraft({ v: 2, comments: [record()] })).toEqual([]);
    expect(normalizeDraft({ comments: [record()] })).toEqual([]);
    expect(normalizeDraft({ v: 1, comments: "nope" })).toEqual([]);
    expect(normalizeDraft(null)).toEqual([]);
  });
});

describe("draft storage", () => {
  function storage(initial = {}) {
    const entries = new Map(Object.entries(initial));
    return {
      getItem: (key) => entries.get(key) ?? null,
      setItem: (key, value) => entries.set(key, value),
      entries,
    };
  }

  test("isolates artifacts that share one origin", () => {
    const store = storage({
      "smfb:first": JSON.stringify({ v: 1, comments: [record({ id: "first-note" })] }),
      "smfb:second": JSON.stringify({ v: 1, comments: [record({ id: "second-note" })] }),
    });

    expect(readDraft(store, "first").map((entry) => entry.id)).toEqual(["first-note"]);
    expect(readDraft(store, "second").map((entry) => entry.id)).toEqual(["second-note"]);
    expect(readDraft(store, "unrelated")).toEqual([]);
  });

  test("returns nothing instead of failing on unusable storage", () => {
    expect(readDraft(null, "first")).toEqual([]);
    expect(readDraft(storage({ "smfb:first": "{not json" }), "first")).toEqual([]);
    expect(readDraft(storage({ "smfb:first": JSON.stringify({ v: 9, comments: [] }) }), "first")).toEqual([]);
    expect(
      readDraft(
        {
          getItem() {
            throw new Error("storage blocked");
          },
        },
        "first",
      ),
    ).toEqual([]);
  });
});
