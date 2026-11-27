/**
 * Reading-column width for the docs reader.
 *
 * The reader exposes `--smd-doc-width` on the `.smd-main` container; this
 * module owns the bounds, the clamp, and localStorage persistence for the
 * mouse-drag width extender.
 */
export const DEFAULT_DOC_WIDTH_REM = 64;
export const MIN_DOC_WIDTH_REM = 40;
export const MAX_DOC_WIDTH_REM = 100;

const STORAGE_KEY = "show-me:doc-width";

/** Clamps a width in rem to the allowed range, falling back to the default. */
export function clampDocWidth(width) {
  if (!Number.isFinite(width)) return DEFAULT_DOC_WIDTH_REM;
  return Math.min(MAX_DOC_WIDTH_REM, Math.max(MIN_DOC_WIDTH_REM, width));
}

/** Reads the persisted width, falling back to the default when unusable. */
export function loadDocWidth(storage = globalThis.localStorage) {
  try {
    const raw = storage?.getItem?.(STORAGE_KEY);
    if (raw == null) return DEFAULT_DOC_WIDTH_REM;
    return clampDocWidth(Number.parseFloat(raw));
  } catch {
    return DEFAULT_DOC_WIDTH_REM;
  }
}

/** Persists the width, clamping before writing. Returns success. */
export function saveDocWidth(width, storage = globalThis.localStorage) {
  if (typeof storage?.setItem !== "function") return false;
  try {
    storage.setItem(STORAGE_KEY, String(clampDocWidth(width)));
    return true;
  } catch {
    return false;
  }
}
