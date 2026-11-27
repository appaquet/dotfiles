import { describe, expect, test } from "bun:test";

// @ts-expect-error -- the module ships plain JS with no type declarations
import {
  clampDocWidth,
  loadDocWidth,
  saveDocWidth,
  DEFAULT_DOC_WIDTH_REM,
  MIN_DOC_WIDTH_REM,
  MAX_DOC_WIDTH_REM,
} from "./show-me-docs-width.js";

function fakeStorage(initial = {}) {
  const data = new Map(Object.entries(initial));
  return {
    getItem: (key) => (data.has(key) ? data.get(key) : null),
    setItem: (key, value) => data.set(key, String(value)),
  };
}

describe("clampDocWidth", () => {
  test("keeps in-range widths unchanged", () => {
    expect(clampDocWidth(64)).toBe(64);
    expect(clampDocWidth(MIN_DOC_WIDTH_REM)).toBe(MIN_DOC_WIDTH_REM);
    expect(clampDocWidth(MAX_DOC_WIDTH_REM)).toBe(MAX_DOC_WIDTH_REM);
  });

  test("clamps to the bounds", () => {
    expect(clampDocWidth(5)).toBe(MIN_DOC_WIDTH_REM);
    expect(clampDocWidth(500)).toBe(MAX_DOC_WIDTH_REM);
  });

  test("falls back to the default for non-finite input", () => {
    expect(clampDocWidth(NaN)).toBe(DEFAULT_DOC_WIDTH_REM);
    expect(clampDocWidth(Infinity)).toBe(DEFAULT_DOC_WIDTH_REM);
    expect(clampDocWidth(undefined)).toBe(DEFAULT_DOC_WIDTH_REM);
  });
});

describe("loadDocWidth", () => {
  test("returns the default when nothing is stored", () => {
    expect(loadDocWidth(fakeStorage())).toBe(DEFAULT_DOC_WIDTH_REM);
    expect(loadDocWidth(null)).toBe(DEFAULT_DOC_WIDTH_REM);
  });

  test("reads the stored value in range", () => {
    expect(loadDocWidth(fakeStorage({ "show-me:doc-width": "70" }))).toBe(70);
  });

  test("falls back to the default for junk", () => {
    expect(loadDocWidth(fakeStorage({ "show-me:doc-width": "not-a-number" }))).toBe(DEFAULT_DOC_WIDTH_REM);
  });

  test("clamps an out-of-range stored value", () => {
    expect(loadDocWidth(fakeStorage({ "show-me:doc-width": "5" }))).toBe(MIN_DOC_WIDTH_REM);
  });
});

describe("saveDocWidth", () => {
  test("persists the clamped width", () => {
    const storage = fakeStorage();
    expect(saveDocWidth(75, storage)).toBe(true);
    expect(storage.getItem("show-me:doc-width")).toBe("75");
  });

  test("clamps before writing", () => {
    const storage = fakeStorage();
    saveDocWidth(5, storage);
    expect(storage.getItem("show-me:doc-width")).toBe(String(MIN_DOC_WIDTH_REM));
  });

  test("reports failure without usable storage", () => {
    expect(saveDocWidth(70, null)).toBe(false);
  });
});
