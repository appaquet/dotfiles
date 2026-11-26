/**
 * Docs reader for show-me. Renders the live Markdown at the current document URL,
 * builds the docs tree from the server inventory, and mounts the shared feedback
 * component once per served root.
 */

import { mountDiagrams } from "/_show-me/diagrams.js";
import { mountFeedback } from "/_show-me/feedback.js";

const MARKDOWN_EXTENSIONS = [".md", ".markdown"];
const TREE_ENDPOINT = "/_show-me/tree";
const HEADING_PATTERN = /^H[1-6]$/;
const HEADING_SELECTOR = "h1, h2, h3, h4, h5, h6";

const els = {
  nav: document.querySelector(".smd-nav"),
  navToggle: document.querySelector(".smd-navtoggle"),
  outline: document.querySelector(".smd-outline"),
  outlineList: document.querySelector(".smd-outline-list"),
  outlineToggle: document.querySelector(".smd-outlinetoggle"),
  title: document.querySelector(".smd-title"),
  path: document.querySelector(".smd-path"),
  state: document.querySelector(".smd-state"),
  doc: document.querySelector(".smd-doc"),
};

const reader = {
  root: { id: "unknown", label: "Docs" },
  paths: [],
  currentPath: "",
  token: 0,
  abort: null,
  feedback: null,
  reducedMotion: window.matchMedia("(prefers-reduced-motion: reduce)").matches,
};

// --- startup ---

start();

async function start() {
  if (!window.marked || !window.DOMPurify) {
    setState("error", "The Markdown renderer could not be loaded. Check the connection and reload.");
    return;
  }

  try {
    const inventory = await fetchTree();
    if (!inventory) throw new Error("tree unavailable");
    reader.root = inventory.root;
    reader.paths = inventory.paths;
  } catch {
    setState("error", "The document list could not be loaded. Reload to try again.");
    return;
  }
  els.title.textContent = reader.root.label;
  reader.feedback = mountFeedback({
    root: () => els.doc,
    artifact: reader.root.id,
    title: "Comments",
    onNavigate: navigateToTarget,
  });

  els.navToggle.addEventListener("click", toggleNavigation);
  els.outlineToggle.addEventListener("click", () => {
    const open = !els.outline.classList.contains("smd-outline-open");
    setOutlineOpen(open);
    if (open) els.outline.scrollIntoView({ block: "start" });
  });
  els.outline.addEventListener("click", followOutlineLink);
  window.addEventListener("popstate", () => {
    // The browser also fires popstate when only the fragment changes, so a
    // same-document fragment must scroll instead of refetching the document.
    if (location.pathname.replace(/^\/+/, "") === reader.currentPath) {
      scrollToFragment(location.hash);
      return;
    }

    showDocument(location.pathname + location.search + location.hash, { push: false });
  });
  window.addEventListener("beforeunload", warnAboutUnsavedComments);
  window.addEventListener("hashchange", () => scrollToFragment(location.hash));
  document.addEventListener("click", interceptDocumentLink);

  await showDocument(location.pathname + location.search + location.hash, { push: false });
}

// --- document loading ---

async function showDocument(target, { push }) {
  const url = new URL(target, location.href);
  const token = (reader.token += 1);
  reader.abort?.abort();
  const abort = (reader.abort = new AbortController());

  setState("loading", "Loading this document…");
  els.doc.replaceChildren();
  els.outlineList.replaceChildren();
  els.outline.hidden = true;
  els.outlineToggle.hidden = true;
  setOutlineOpen(false);
  const inventoryRequest = fetchTree();

  let text;
  try {
    const response = await fetch(`${url.pathname}?raw=1`, { cache: "no-store", signal: abort.signal });
    if (token !== reader.token) return;
    if (response.status === 404) {
      setState("missing", "This document does not exist.");
      return;
    }
    if (!response.ok) {
      setState("error", "This document could not be loaded. Reload to try again.");
      return;
    }
    text = await response.text();
  } catch (error) {
    if (token !== reader.token || error?.name === "AbortError") return;
    setState("error", "This document could not be loaded. Reload to try again.");
    return;
  }
  if (token !== reader.token) return;

  const inventory = await inventoryRequest;
  if (inventory) {
    reader.root = inventory.root;
    reader.paths = inventory.paths;
  }
  if (token !== reader.token) return;
  reader.currentPath = url.pathname.replace(/^\/+/, "");
  els.path.textContent = url.pathname;
  document.title = `${fileName(url.pathname)} · ${reader.root.label}`;

  if (text.trim() === "") {
    setState("empty", "This document is empty.");
    reader.feedback?.setTargets([]);
  } else {
    await renderDocument(text, url, abort.signal);
    // Diagram rendering yields for the Mermaid import and each diagram, so a
    // navigation that started meanwhile owns the DOM now.
    if (token !== reader.token) return;
    setState(null, "");
  }

  renderTree();
  if (push) history.pushState({}, "", url.pathname + url.search + url.hash);
  scrollToFragment(url.hash);
  closeNavigation();
}

async function renderDocument(text, documentUrl, signal) {
  const rendered = window.marked.parse(text, { gfm: true });
  els.doc.innerHTML = window.DOMPurify.sanitize(rendered, { USE_PROFILES: { html: true } });
  await mountDiagrams(els.doc, { signal });
  if (signal?.aborted) return;

  const headings = prepareHeadings();
  renderCallouts();
  detachRemoteImages(documentUrl);
  reader.feedback?.setTargets(buildSections());
  renderOutline(headings);
}

// --- rendering ---

/** Give every heading a stable id and the anchor that shares its section. */
function prepareHeadings() {
  const used = new Set();
  const headings = els.doc.querySelectorAll(HEADING_SELECTOR);
  for (const heading of headings) {
    const base = slugify(heading.textContent) || "section";
    let id = base;
    let suffix = 1;
    while (used.has(id)) id = `${base}-${suffix++}`;
    used.add(id);
    heading.id = id;
    heading.append(sectionAnchor(id));
  }
  return headings;
}

function sectionAnchor(id) {
  const anchor = document.createElement("a");
  anchor.className = "smd-anchor";
  anchor.href = sectionHref(id);
  anchor.textContent = "#";
  anchor.setAttribute("aria-label", "Link to this section");
  return anchor;
}

/** Heading text without the section anchor, for comment labels and quotes. */
function headingLabel(heading) {
  const clone = heading.cloneNode(true);
  clone.querySelector(".smd-anchor")?.remove();
  return clone.textContent.trim();
}

function renderOutline(headings) {
  const parents = [];
  for (const heading of headings) {
    const rank = Number(heading.tagName[1]);
    while (parents.length > 0 && parents.at(-1).rank >= rank) parents.pop();

    const item = document.createElement("li");
    const link = document.createElement("a");
    link.href = sectionHref(heading.id);
    link.textContent = headingLabel(heading) || heading.id;
    item.append(link);

    const parent = parents.at(-1);
    if (parent && !parent.list) {
      parent.list = document.createElement("ul");
      parent.item.append(parent.list);
    }
    (parent?.list ?? els.outlineList).append(item);
    parents.push({ rank, item, list: null });
  }

  els.outline.hidden = headings.length === 0;
  els.outlineToggle.hidden = els.outline.hidden;
}

function setOutlineOpen(open) {
  els.outline.classList.toggle("smd-outline-open", open);
  els.outlineToggle.setAttribute("aria-expanded", String(open));
}

function followOutlineLink(event) {
  if (!isPlainClick(event) || els.outlineToggle.getClientRects().length === 0) return;
  const link = event.target.closest?.("a[href]");
  const heading = link && fragmentTarget(link.hash);
  if (!heading) return;

  // Move focus out of the disclosure while leaving the native fragment jump intact.
  setOutlineOpen(false);
  heading.tabIndex = -1;
  heading.focus({ preventScroll: true });
}

function renderCallouts() {
  for (const quote of els.doc.querySelectorAll("blockquote")) {
    const first = quote.querySelector("p");
    const match = first?.textContent.match(/^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*/i);
    if (!match) continue;

    const kind = match[1].toUpperCase();
    first.textContent = first.textContent.slice(match[0].length);
    quote.classList.add("smd-callout", `smd-callout-${kind.toLowerCase()}`);

    const label = document.createElement("p");
    label.className = "smd-callout-label";
    label.textContent = `${kind[0]}${kind.slice(1).toLowerCase()}`;
    quote.prepend(label);
  }
}

function detachRemoteImages(documentUrl) {
  for (const image of els.doc.querySelectorAll("img")) {
    const source = image.getAttribute("src") ?? "";
    let resolved = null;
    try {
      resolved = new URL(source, documentUrl);
    } catch {
      resolved = null;
    }
    if (resolved && resolved.origin === location.origin) continue;

    const note = document.createElement("span");
    note.className = "smd-remote-image";
    note.append("External image not loaded: ");
    if (resolved && /^https?:$/.test(resolved.protocol)) {
      const link = document.createElement("a");
      link.href = resolved.href;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = image.getAttribute("alt") || resolved.href;
      note.append(link);
    } else {
      note.append(image.getAttribute("alt") || source);
    }
    image.replaceWith(note);
  }
}

/**
 * Wrap the rendered document into one section per heading and register each as a
 * comment target, so whole-section and passage comments share one identity.
 */
function buildSections() {
  const targets = [];
  const fragment = document.createDocumentFragment();
  let section = null;

  for (const node of [...els.doc.childNodes]) {
    const isHeading = node.nodeType === 1 && HEADING_PATTERN.test(node.nodeName);
    if (isHeading || !section) {
      section = document.createElement("section");
      section.className = "smd-section";
      fragment.append(section);

      if (isHeading) {
        const label = headingLabel(node);
        const targetId = `${reader.currentPath}#${node.id}`;
        section.dataset.targetId = targetId;
        targets.push({
          id: targetId,
          label,
          sourceId: reader.currentPath,
          sourceLabel: reader.currentPath,
          element: section,
        });
      }
    }
    section.append(node);
  }

  els.doc.replaceChildren(fragment);
  return targets;
}

// --- docs tree ---

function renderTree() {
  const tree = { folders: new Map(), files: [] };
  for (const documentPath of reader.paths) {
    const parts = documentPath.split("/");
    let node = tree;
    for (const part of parts.slice(0, -1)) {
      if (!node.folders.has(part)) node.folders.set(part, { folders: new Map(), files: [] });
      node = node.folders.get(part);
    }
    node.files.push({ name: parts[parts.length - 1], path: documentPath });
  }

  els.nav.replaceChildren();
  if (reader.paths.length === 0) {
    const empty = document.createElement("p");
    empty.className = "smd-nav-empty";
    empty.textContent = "No Markdown documents found.";
    els.nav.append(empty);
    return;
  }
  els.nav.append(renderTreeLevel(tree, ""));
}

function renderTreeLevel(node, prefix) {
  const list = document.createElement("ul");

  for (const [name, child] of [...node.folders].sort(([left], [right]) => (left < right ? -1 : 1))) {
    const folderPath = prefix === "" ? name : `${prefix}/${name}`;
    const item = document.createElement("li");
    const details = document.createElement("details");
    details.open = reader.currentPath === folderPath || reader.currentPath.startsWith(`${folderPath}/`);
    const summary = document.createElement("summary");
    summary.textContent = `${name}/`;
    details.append(summary, renderTreeLevel(child, folderPath));
    item.append(details);
    list.append(item);
  }

  for (const file of [...node.files].sort((left, right) => (left.name < right.name ? -1 : 1))) {
    const item = document.createElement("li");
    const link = document.createElement("a");
    link.href = `/${file.path.split("/").map(encodeURIComponent).join("/")}`;
    link.textContent = file.name;
    if (file.path === reader.currentPath) link.setAttribute("aria-current", "page");
    item.append(link);
    list.append(item);
  }

  return list;
}

function toggleNavigation() {
  const open = els.nav.classList.toggle("smd-nav-open");
  els.navToggle.setAttribute("aria-expanded", String(open));
}

function closeNavigation() {
  els.nav.classList.remove("smd-nav-open");
  els.navToggle.setAttribute("aria-expanded", "false");
}

// --- navigation ---

function interceptDocumentLink(event) {
  if (!isPlainClick(event)) return;

  const anchor = event.target.closest?.("a[href]");
  if (!anchor || anchor.target === "_blank") return;

  const url = new URL(anchor.getAttribute("href"), location.href);
  if (url.origin !== location.origin || !isMarkdown(url.pathname)) return;

  // A fragment in this same document is plain anchor navigation: the browser
  // updates the URL and scrolls, so there is nothing to fetch or re-render.
  if (url.hash !== "" && url.pathname === location.pathname) return;

  event.preventDefault();
  showDocument(url.pathname + url.search + url.hash, { push: true });
}

async function navigateToTarget({ targetId }) {
  const separator = targetId.indexOf("#");
  const documentPath = separator === -1 ? targetId : targetId.slice(0, separator);
  const fragment = separator === -1 ? "" : targetId.slice(separator + 1);

  if (documentPath !== reader.currentPath) {
    await showDocument(`/${documentPath}${fragment === "" ? "" : `#${fragment}`}`, { push: true });
    return;
  }

  const section = findSection(targetId);
  section?.scrollIntoView({
    block: "start",
    behavior: reader.reducedMotion ? "auto" : "smooth",
  });
}

function findSection(targetId) {
  return [...els.doc.querySelectorAll("[data-target-id]")].find(
    (section) => section.dataset.targetId === targetId,
  );
}

function scrollToFragment(hash) {
  for (const linked of els.doc.querySelectorAll(".smd-linked")) linked.classList.remove("smd-linked");
  els.outlineList.querySelector('[aria-current="location"]')?.removeAttribute("aria-current");

  const target = fragmentTarget(hash);
  if (!target) return;

  target.scrollIntoView({ block: "start" });
  target.classList.add("smd-linked");
  const link = els.outlineList.querySelector(`a[href="${sectionHref(target.id)}"]`);
  link?.setAttribute("aria-current", "location");
}

function fragmentTarget(hash) {
  if (!hash || hash === "#") return null;

  let id;
  try {
    id = decodeURIComponent(hash.slice(1));
  } catch {
    return null;
  }

  const selector = `#${CSS.escape(id)}`;
  return els.doc.querySelector(`:is(${HEADING_SELECTOR})${selector}`)
    ?? els.doc.querySelector(selector);
}

function warnAboutUnsavedComments(event) {
  if (!reader.feedback || reader.feedback.isPersistent()) return;
  if (reader.feedback.getComments().length === 0) return;
  event.preventDefault();
  event.returnValue = "";
}

// --- helpers ---

function isPlainClick(event) {
  return !event.defaultPrevented && event.button === 0
    && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey;
}

function sectionHref(id) {
  return `#${encodeURIComponent(id)}`;
}

async function fetchTree() {
  try {
    const response = await fetch(TREE_ENDPOINT, { cache: "no-store" });
    if (!response.ok) return null;
    const inventory = await response.json();
    if (!inventory?.root?.id || !Array.isArray(inventory.paths)) return null;
    return inventory;
  } catch {
    return null;
  }
}
function setState(kind, message) {
  els.state.dataset.kind = kind ?? "";
  els.state.textContent = message;
  els.state.hidden = message === "";
}

function isMarkdown(pathname) {
  const lower = pathname.toLowerCase();
  return MARKDOWN_EXTENSIONS.some((extension) => lower.endsWith(extension));
}

function fileName(pathname) {
  return pathname.split("/").pop() || "/";
}

function slugify(text) {
  return text
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "-")
    .replace(/^-+|-+$/g, "");
}
