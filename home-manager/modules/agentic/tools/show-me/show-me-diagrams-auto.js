/**
 * Zero-configuration diagram entry for authored artifacts.
 *
 * A page needs one module tag plus `pre.mermaid` blocks. The pinned Mermaid
 * build, the palette, and the failure handling come from `diagrams.js`, so no
 * artifact repeats a CDN URL, a version, or theme initialization.
 */

import { mountDiagrams } from "/_show-me/diagrams.js";

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => mountDiagrams(), { once: true });
} else {
  mountDiagrams();
}
