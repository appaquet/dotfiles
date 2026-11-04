/**
 * Zero-configuration entry for the shared feedback component.
 *
 * A page needs one module tag. This module mounts a single feedback instance
 * over the page's text and registers the targets the markup already declares,
 * so no host script is required. The explicit `mountFeedback` API in
 * `feedback.js` stays the way to drive a multi-document or custom host.
 */

import { mountFeedback } from "/_show-me/feedback.js";

const HEADING_SELECTOR = "h1, h2, h3, h4, h5, h6";
const ROOT_SELECTOR = "[data-smfb-root]";
const MOUNTED_ATTRIBUTE = "data-smfb-mounted";

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}

/** Mounts the component and publishes its controller as `window.showMeFeedback`. */
async function start() {
  // Claimed before the stylesheet wait, which defers publishing the controller:
  // a second copy of this entry would otherwise mount a duplicate instance.
  if (document.documentElement.hasAttribute(MOUNTED_ATTRIBUTE) || window.showMeFeedback) return;
  document.documentElement.setAttribute(MOUNTED_ATTRIBUTE, "");

  const source = pageSource();
  const root = document.querySelector(ROOT_SELECTOR) ?? document.querySelector("main") ?? document.body;

  // The drawer's closed look lives in the stylesheet: a component mounted before
  // that sheet applies paints the drawer in page flow, then slides it away.
  await loadStylesheet();
  const feedback = mountFeedback({
    root,
    artifact: document.body.dataset.smfbArtifact?.trim() || source,
    title: "Comments",
  });

  feedback.setTargets(buildTargets(root, source));
  window.showMeFeedback = feedback;
}

/** Root-relative page path, which identifies this page in stored comments. */
function pageSource() {
  let path = window.location.pathname;

  try {
    path = decodeURIComponent(path);
  } catch {
    // A malformed escape keeps the raw path rather than breaking the page.
  }

  path = path.replace(/^\/+/, "");
  return path === "" ? "index.html" : path;
}

/**
 * Targets taken from the regions the page marks with `data-target-id`.
 *
 * A page that marks no region is one page-wide target, so its prose is still
 * commentable. Marked regions keep the authored DOM untouched: the component
 * reads them and never restructures the page.
 */
function buildTargets(root, source) {
  const sourceLabel = document.title.trim() || source;
  const seen = new Set();
  const targets = [];

  // The root itself may be one of the marked regions, so it is scanned first.
  for (const element of [root, ...root.querySelectorAll("[data-target-id]")]) {
    const id = element.dataset.targetId?.trim();
    if (!id || seen.has(id)) continue;

    seen.add(id);
    targets.push({ id, label: regionLabel(element, id), sourceId: source, sourceLabel, element });
  }

  if (targets.length === 0) {
    targets.push({ id: source, label: sourceLabel, sourceId: source, sourceLabel, element: root });
  }

  return targets;
}

function regionLabel(element, targetId) {
  const authored = element.dataset.targetLabel?.trim();
  if (authored) return authored;

  const heading = element.matches(HEADING_SELECTOR) ? element : element.querySelector(HEADING_SELECTOR);
  return heading?.textContent.trim() || targetId;
}

/**
 * Applies the component stylesheet, resolving once it is loaded or has failed.
 *
 * A failure still resolves: the component mounts unstyled rather than not at all.
 */
function loadStylesheet() {
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = "/_show-me/feedback.css";
  link.dataset.smfbStylesheet = "";
  document.head.append(link);

  return new Promise((resolve) => {
    link.addEventListener("load", resolve, { once: true });
    link.addEventListener("error", resolve, { once: true });
  });
}
